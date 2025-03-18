use actix_cors::Cors;
use actix_files::Files;
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use clap::{Arg, Command};
use serde_json::json;
use std::fs;

use backend::schema_types::Config;
use backend::workspace::Workspace;
use backend::{
    handle_error, process_artifacts, run_json2nix, run_nix_build, validate_config,
    write_default_nix,
};

// Embed the flake files at compile time.
const FLAKE_NIX: &str = include_str!("static/flake.nix");

// A static array of allowed filenames in the build output.
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

    // Prepend boilerplate and write default.nix.
    if let Err(e) = write_default_nix(&workspace.hostname_dir, &json2nix_output) {
        return handle_error("Failed to write default.nix file", e);
    }

    // Write the embedded flake file.
    let flake_nix_path = workspace.nix_config_dir.join("flake.nix");
    if let Err(e) = fs::write(&flake_nix_path, FLAKE_NIX) {
        return handle_error("Failed to write flake.nix", e);
    }

    // Run nix build.
    if let Err(e) = run_nix_build(&workspace.nix_config_dir, &hostname, &workspace.out_link) {
        return handle_error("Failed to run nix build", e);
    }
    println!("Nix build completed.");

    // Retrieve the build id and pre-created output directory.
    let build_id = &workspace.uuid;
    let output_dir = workspace.output_dir.clone();

    // Copy whitelisted results, and compute their SHA256's.
    let artifacts_info =
        match process_artifacts(&workspace.out_link, &output_dir, build_id, WHITELIST) {
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
