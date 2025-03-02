use actix_cors::Cors;
use actix_files::Files;
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use clap::{Arg, Command};
use serde_json::json;
use std::fs;

use backend::schema_types::Config;
use backend::workspace::Workspace;
use backend::{compute_sha256, create_tarball, run_json2nix, run_nix_build, write_default_nix};

// Embed the flake files at compile time.
const FLAKE_NIX: &str = include_str!("static/flake.nix");

/// Application state.
struct AppState {
    workspace: Workspace,
    base_url: String,
}

async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(json!({ "status": "ok" }))
}

/// Accepts strongly typed JSON and then processes it.
async fn nixos_config(config: web::Json<Config>, data: web::Data<AppState>) -> impl Responder {
    // Serialize the typed config into a JSON string.
    let json_str = match serde_json::to_string(&*config) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("JSON Serialization Error: {:?}", e);
            return HttpResponse::BadRequest().json(json!({
                "status": "error",
                "message": "Failed to serialize JSON"
            }));
        }
    };

    // Extract hostname from the config.
    let hostname = config.localization.hostname.clone();

    // Create a unique build workspace.
    let workspace = match data.workspace.new_build_workspace(&hostname) {
        Ok(ws) => ws,
        Err(e) => {
            eprintln!("Failed to create workspace: {:?}", e);
            return HttpResponse::InternalServerError().json(json!({
                "status": "error",
                "message": "Failed to create workspace"
            }));
        }
    };

    // Run json2nix.
    let json2nix_output = match run_json2nix(&json_str) {
        Ok(out) => out,
        Err(e) => {
            eprintln!("Failed to run json2nix: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "status": "error",
                "message": "Failed to run json2nix"
            }));
        }
    };

    // Prepend boilerplate and write default.nix.
    if let Err(e) = write_default_nix(&workspace.hostname_dir, &json2nix_output) {
        eprintln!("Failed to write default.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to write default.nix file"
        }));
    }

    // Write the embedded flake file.
    let flake_nix_path = workspace.nix_config_dir.join("flake.nix");
    if let Err(e) = fs::write(&flake_nix_path, FLAKE_NIX) {
        eprintln!("Failed to write flake.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to write flake.nix"
        }));
    }

    // Run nix build.
    if let Err(e) = run_nix_build(&workspace.nix_config_dir, &hostname, &workspace.out_link) {
        eprintln!("Failed to run nix build: {}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to run nix build"
        }));
    }
    println!("Nix build completed.");

    // Create a tarball for the nixConfig directory.
    let nixconfig_tar = workspace.working_dir.join("nixConfig.tar");
    if let Err(e) = create_tarball(&workspace.nix_config_dir, "nixConfig", &nixconfig_tar) {
        eprintln!("Failed to create nixConfig.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to create nixConfig.tar"
        }));
    }

    // Create a tarball for kexecTree (resolve symlinks).
    let kexec_tree_real = match fs::canonicalize(&workspace.out_link) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Failed to resolve kexecTree symlink: {:?}", e);
            return HttpResponse::InternalServerError().json(json!({
                "status": "error",
                "message": "Failed to resolve kexecTree"
            }));
        }
    };

    let kexec_tar = workspace.working_dir.join("kexecTree.tar");
    if let Err(e) = create_tarball(&kexec_tree_real, "kexecTree", &kexec_tar) {
        eprintln!("Failed to create kexecTree.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to create kexecTree.tar"
        }));
    }

    // Compute SHA-256 hashes.
    let nix_hash = match compute_sha256(&nixconfig_tar) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("Failed to compute SHA256 for nixConfig.tar: {:?}", e);
            return HttpResponse::InternalServerError().json(json!({
                "status": "error",
                "message": "Failed to compute SHA256 for nixConfig.tar"
            }));
        }
    };

    let kexec_hash = match compute_sha256(&kexec_tar) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("Failed to compute SHA256 for kexecTree.tar: {:?}", e);
            return HttpResponse::InternalServerError().json(json!({
                "status": "error",
                "message": "Failed to compute SHA256 for kexecTree.tar"
            }));
        }
    };

    // Write the hashes to verify.txt.
    let verify_txt = format!("nixConfig.tar {}\nkexecTree.tar {}\n", nix_hash, kexec_hash);
    let verify_path = workspace.working_dir.join("verify.txt");
    if let Err(e) = fs::write(&verify_path, verify_txt.as_bytes()) {
        eprintln!("Failed to write verify.txt: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to write verify.txt"
        }));
    }

    // Move final artifacts into a build-specific subfolder within the top-level
    let build_id = workspace.uuid.clone();
    let builds_dir = data.workspace.base_dir.path().join("builds");
    let _ = fs::create_dir_all(&builds_dir);
    let build_dir = builds_dir.join(&build_id);
    if let Err(e) = fs::create_dir_all(&build_dir) {
        eprintln!("Failed to create build subfolder: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to create build subfolder"
        }));
    }
    if let Err(e) = fs::rename(nixconfig_tar, build_dir.join("nixConfig.tar")) {
        eprintln!("Failed to move nixConfig.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to move nixConfig.tar"
        }));
    }
    if let Err(e) = fs::rename(kexec_tar, build_dir.join("kexecTree.tar")) {
        eprintln!("Failed to move kexecTree.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to move kexecTree.tar"
        }));
    }
    if let Err(e) = fs::rename(verify_path, build_dir.join("verify.txt")) {
        eprintln!("Failed to move verify.txt: {:?}", e);
        return HttpResponse::InternalServerError().json(json!({
            "status": "error",
            "message": "Failed to move verify.txt"
        }));
    }

    // Return download links pointing to the new build-specific folder.
    let download_links = vec![
        format!("/builds/{}/nixConfig.tar", build_id),
        format!("/builds/{}/kexecTree.tar", build_id),
        format!("/builds/{}/verify.txt", build_id),
    ];

    HttpResponse::Ok().json(json!({
        "download_links": download_links,
        "status": "ok"
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

    println!("Running on: {}", base_url);

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
