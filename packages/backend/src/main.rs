use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use actix_files::Files;
use actix_cors::Cors;
use clap::{Command, Arg};
use serde_json::Value;
use std::process::{Command as StdCommand, Stdio};
use std::path::Path;
use std::io::Write;
use std::fs;

// Embed the flake files at compile time.
const FLAKE_NIX: &str = include_str!("static/flake.nix");
const FLAKE_LOCK: &str = include_str!("static/flake.lock");

async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({ "status": "ok" }))
}

/// Accepts arbitrary JSON (for now), and then processes it.
async fn nixos_config(config: web::Json<Value>, output_dir: web::Data<String>) -> impl Responder {

    // Extract the hostname using a JSON pointer.
    let hostname = if let Some(host) = config.pointer("/localization/hostname").and_then(|v| v.as_str()) {
        host.to_string()
    } else {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "status": "error",
            "message": "Missing localization.hostname"
        }));
    };

    // Convert the received JSON into a string.
    let json_str = match serde_json::to_string(&config.into_inner()) {
        Ok(json) => json,
        Err(e) => {
            eprintln!("JSON Serialization Error: {:?}", e);
            return HttpResponse::BadRequest().json(serde_json::json!({
                "status": "error",
                "message": "Invalid JSON"
            }));
        }
    };

    // Use the provided output directory.
    let output = output_dir.get_ref();

    // Create nixosConfigurations/<hostname> inside the output directory.
    let nix_config_dir = format!("{}/nixosConfigurations/{}", output, hostname);
    if let Err(e) = fs::create_dir_all(&nix_config_dir) {
        eprintln!("Failed to create nixosConfigurations directory '{}': {:?}", nix_config_dir, e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": format!("Failed to create directory '{}'", nix_config_dir)
        }));
    }

    // Run json2nix and pipe JSON data into its stdin.
    let json2nix_output = StdCommand::new("json2nix")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn();

    let child = match json2nix_output {
        Ok(mut child) => {
            if let Err(e) = child.stdin.as_mut().unwrap().write_all(json_str.as_bytes()) {
                eprintln!("Failed to write to stdin of json2nix: {:?}", e);
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "status": "error",
                    "message": "Failed to pipe JSON to json2nix"
                }));
            }
            child.wait_with_output()
        }
        Err(e) => {
            eprintln!("Failed to spawn json2nix process: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to spawn json2nix process"
            }));
        }
    };

    let output_child = match child {
        Ok(output) => output,
        Err(e) => {
            eprintln!("Command execution failed: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to execute json2nix"
            }));
        }
    };

    let stdout = String::from_utf8_lossy(&output_child.stdout);
    let stderr = String::from_utf8_lossy(&output_child.stderr);

    if !output_child.status.success() {
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": stderr
        }));
    }

    // Prepend boilerplate and write default.nix into nixosConfigurations/<hostname>.
    let nix_boilerplate = format!("{{ pkgs, lib, config, ... }}: {{ homestakeros = {}; }}", stdout);
    let default_nix_path = format!("{}/default.nix", nix_config_dir);
    if let Err(e) = fs::write(&default_nix_path, nix_boilerplate.as_bytes()) {
        eprintln!("Failed to write default.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write default.nix file"
        }));
    }

    // Write the embedded flake files into the output directory.
    if let Err(e) = fs::write(format!("{}/flake.nix", output), FLAKE_NIX) {
        eprintln!("Failed to write flake.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write flake.nix"
        }));
    }
    if let Err(e) = fs::write(format!("{}/flake.lock", output), FLAKE_LOCK) {
        eprintln!("Failed to write flake.lock: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write flake.lock"
        }));
    }

    // Run nix build with --out-link <output>/result.
    let build_arg = format!("path:{}#nixosConfigurations.{}.config.system.build.kexecTree", output, hostname);
    let out_link = format!("{}/result", output);
    let build_output = StdCommand::new("nix")
        .arg("build")
        .arg(build_arg)
        .arg("--out-link")
        .arg(&out_link)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output();

    let build_output = match build_output {
        Ok(output) => output,
        Err(e) => {
            eprintln!("Failed to execute nix build: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to execute nix build"
            }));
        }
    };

    let build_stdout = String::from_utf8_lossy(&build_output.stdout);
    let build_stderr = String::from_utf8_lossy(&build_output.stderr);

    if !build_output.status.success() {
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": build_stderr
        }));
    }

    println!("Nix build stdout: {}", build_stdout);
    println!("Nix build stderr: {}", build_stderr);

    // Verify that the result directory exists.
    let result_path = Path::new(&out_link);
    if result_path.exists() && result_path.is_dir() {
        HttpResponse::Ok().json(serde_json::json!({
            "status": "ok",
            "message": "Files available at: /result"
        }))
    } else {
        HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Result directory not found"
        }))
    }
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
        .arg(
            Arg::new("output")
                .short('o')
                .long("output")
                .value_name("OUTPUT")
                .default_value("./file-server")
                .help("Output directory for generated files"),
        )
        .get_matches();

    let addr = matches.get_one::<String>("addr").unwrap();
    let port = matches.get_one::<String>("port").unwrap();
    let output = matches.get_one::<String>("output").unwrap().clone();

    // Ensure the output directory exists at startup.
    if let Err(e) = fs::create_dir_all(&output) {
        eprintln!("Failed to create output directory '{}': {:?}", output, e);
    }

    // Pass the output directory into app data.
    let output_data = web::Data::new(output.clone());

    // Start the Actix server.
    HttpServer::new(move || {
        App::new()
            .app_data(output_data.clone())
            .wrap(Cors::permissive())
            .route("/", web::get().to(health_check))
            .route("/nixosConfig", web::post().to(nixos_config))
            .service(Files::new("/result", format!("{}", output)).show_files_listing())
    })
    .bind(format!("{}:{}", addr, port))?
    .run()
    .await
}
