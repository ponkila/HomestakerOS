use actix_cors::Cors;
use actix_files::Files;
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use clap::{Arg, Command};
use serde_json::json;
use std::fs;

use backend::schema_types::Config;
use backend::workspace::Workspace;
use backend::{
    create_tarball, handle_error, process_artifacts, run_json2nix, run_nix_build, update_hostnames,
    update_schema, validate_config, write_default_nix, write_json_to_file,
};

// Embed the flake files at compile time.
const FLAKE_NIX: &str = include_str!("static/flake.nix");

// A static array of allowed filenames in the nix build output.
const WHITELIST: &[&str] = &["bzImage", "initrd.zst", "kexec-boot"];

/// Application state.
struct AppState {
    workspace: Workspace,
    base_url: String,
}

async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(json!({ "status": "ok" }))
}

/// Accepts strongly typed JSON and then processes it.
async fn nixos_config(req_body: String, data: web::Data<AppState>) -> impl Responder {
    // Parse the request body manually; we can catch errors ourselves.
    let config: Config = match serde_json::from_str(&req_body) {
        Ok(cfg) => cfg,
        Err(e) => {
            return handle_error("Failed to parse JSON", e);
        }
    };

    // Serialize the typed config into a JSON string.
    let json_str = match serde_json::to_string(&config) {
        Ok(s) => s,
        Err(e) => {
            return handle_error("Failed to serialize JSON", e);
        }
    };

    // Validate that required fields are not empty.
    if let Err(e) = validate_config(&config) {
        return handle_error("Failed to validate JSON", e);
    }

    // Print the input JSON string.
    println!("Input JSON string: {json_str}");

    // Extract hostname from the config.
    let hostname = config.localization.hostname.clone();

    // Create a unique build workspace.
    let workspace = match data.workspace.new_build_workspace(&hostname) {
        Ok(ws) => ws,
        Err(e) => return handle_error("Failed to create workspace", e),
    };

    // Run json2nix.
    let json2nix_output = match run_json2nix(&json_str) {
        Ok(out) => out,
        Err(e) => return handle_error("Failed to run json2nix", e),
    };

    // Output the original JSON to default.json
    let default_json_path = workspace.hostname_dir.join("default.json");
    if let Err(e) = write_json_to_file(&default_json_path, &json_str) {
        return handle_error("Failed to write default.json file", e);
    }

    // Prepend boilerplate and write default.nix.
    if let Err(e) = write_default_nix(&workspace.hostname_dir, &json2nix_output) {
        return handle_error("Failed to write default.nix file", e);
    }

    // Write the embedded flake file.
    let flake_nix_path = workspace.nix_config_dir.join("flake.nix");
    if let Err(e) = fs::write(&flake_nix_path, FLAKE_NIX) {
        return handle_error("Failed to write flake.nix", e);
    }

    // Fetch hostnames.json.
    let hostnames_output = workspace
        .nix_config_dir
        .join("nixosConfigurations/hostnames.json");
    if let Err(e) = update_hostnames(&hostnames_output, &workspace.nix_config_dir) {
        return handle_error("Failed to write hostnames.json", e);
    }

    // Fetch options.json.
    let schema_output = workspace
        .nix_config_dir
        .join("nixosModules/homestakeros/options.json");
    if let Err(e) = update_schema(&schema_output, &workspace.nix_config_dir) {
        return handle_error("Failed to write options.json", e);
    }

    // Retrieve the build id and pre-created output directory.
    let build_id = &workspace.uuid;
    let output_dir = workspace.output_dir.clone();

    // Create nixConfig.tar.
    if let Err(e) = create_tarball(&workspace.nix_config_dir, &output_dir, "nixConfig.tar") {
        return handle_error("Failed to create nixConfig.tar", e);
    }

    // Run nix build.
    if let Err(e) = run_nix_build(&workspace.nix_config_dir, &hostname, &output_dir, WHITELIST) {
        return handle_error("Failed to run nix build", e);
    }
    println!("Nix build completed.");

    // Process all files from the output directory.
    let artifacts_info = match process_artifacts(&output_dir, build_id) {
        Ok(info) => info,
        Err(e) => return handle_error("Failed to process artifacts", e),
    };

    // Return artifacts in JSON
    HttpResponse::Ok().json(json!({
        "status": "ok",
        "build_id": build_id,
        "artifacts": artifacts_info
    }))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("HomestakerOS")
        .version("0.2.0")
        .author("Jesse Karjalainen <jesse@ponkila.com>")
        .about("A tool for compiling a HomestakerOS")
        .arg(
            Arg::new("addr")
                .short('a')
                .long("addr")
                .value_name("ADDR")
                .default_value("0.0.0.0")
                .help("Host address to bind the server"),
        )
        .arg(
            Arg::new("port")
                .short('p')
                .long("port")
                .value_name("PORT")
                .default_value("8081")
                .help("Port to bind the server"),
        )
        .get_matches();

    let addr = matches.get_one::<String>("addr").unwrap();
    let port = matches.get_one::<String>("port").unwrap();
    let base_url = "http://".to_string() + addr + ":" + port;

    println!("Running on: {base_url}");

    // Create a Workspace singleton.
    let workspace = Workspace::new().expect("Failed to create workspace");
    println!(
        "Using temporary directory: {}",
        workspace.base_dir.path().display()
    );

    let app_state = web::Data::new(AppState {
        workspace,
        base_url,
    });

    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .wrap(Cors::permissive())
            .route("/", web::get().to(health_check))
            .route("/nixosConfig", web::post().to(nixos_config))
            .service(
                Files::new(
                    "/builds",
                    app_state.workspace.base_dir.path().join("builds"),
                )
                .prefer_utf8(true)
                .show_files_listing(),
            )
    })
    .bind(addr.to_string() + ":" + port)?
    .run()
    .await
}
