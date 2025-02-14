use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use actix_files::Files;
use actix_cors::Cors;
use clap::{Command, Arg};
use serde_json::Value;
use std::process::{Command as StdCommand, Stdio};
use std::path::Path;
use std::io::{Write, Read, BufReader};
use std::fs;
use tempfile::TempDir;
use tar::Builder;
use sha2::{Sha256, Digest};

// Embed the flake files at compile time.
const FLAKE_NIX: &str = include_str!("static/flake.nix");

/// Application state.
struct AppState {
    temp_dir: TempDir,
    base_url: String,
}

async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({ "status": "ok" }))
}

/// Accepts arbitrary JSON (for now), and then processes it.
async fn nixos_config(config: web::Json<Value>, data: web::Data<AppState>) -> impl Responder {

    // Extract the hostname using a JSON pointer.
    let hostname = if let Some(host) = config.pointer("/localization/hostname").and_then(|v| v.as_str()) {
        host.to_string()
    } else {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "status": "error",
            "message": "Missing localization.hostname"
        }));
    };

    // Ensure that ssh.authorizedKeys is provided and contains at least one entry.
    if let Some(keys) = config.pointer("/ssh/authorizedKeys").and_then(|v| v.as_array()) {
        if keys.is_empty() {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "status": "error",
                "message": "ssh.authorizedKeys must contain at least one entry"
            }));
        }
    } else {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "status": "error",
            "message": "Missing ssh.authorizedKeys"
        }));
    }

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
    let output_dir = data.temp_dir.path();

    // Create a base directory for the nix files.
    let nix_config_dir = output_dir.join("nixConfig");
    if let Err(e) = fs::create_dir_all(&nix_config_dir) {
        eprintln!("Failed to create nixConfig directory '{}': {:?}", nix_config_dir.display(), e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": format!("Failed to create directory '{}'", nix_config_dir.display())
        }));
    }

    // Create a hostname-specific directory.
    let hostname_dir = nix_config_dir.join("nixosConfigurations").join(&hostname);
    if let Err(e) = fs::create_dir_all(&hostname_dir) {
        eprintln!("Failed to create hostname directory '{}': {:?}", hostname_dir.display(), e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": format!("Failed to create directory for hostname '{}'", hostname)
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
            match child.stdin.as_mut() {
                Some(stdin) => {
                    if let Err(e) = stdin.write_all(json_str.as_bytes()) {
                        eprintln!("Failed to write to stdin of json2nix: {:?}", e);
                        return HttpResponse::InternalServerError().json(serde_json::json!({
                            "status": "error",
                            "message": "Failed to pipe JSON to json2nix"
                        }));
                    }
                }
                None => {
                    eprintln!("Failed to open stdin for json2nix");
                    return HttpResponse::InternalServerError().json(serde_json::json!({
                        "status": "error",
                        "message": "Failed to open stdin for json2nix"
                    }));
                }
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

    // Prepend boilerplate and write default.nix.
    let nix_boilerplate = format!("{{ pkgs, lib, config, ... }}: {{ homestakeros = {}; }}", stdout);
    let default_nix_path = hostname_dir.join("default.nix");
    if let Err(e) = fs::write(&default_nix_path, nix_boilerplate.as_bytes()) {
        eprintln!("Failed to write default.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write default.nix file"
        }));
    }

    // Write the embedded flake file.
    let flake_nix_path = nix_config_dir.join("flake.nix");
    if let Err(e) = fs::write(&flake_nix_path, FLAKE_NIX) {
        eprintln!("Failed to write flake.nix: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write flake.nix"
        }));
    }

    // Run nix build.
    let nix_config_dir_str = format!("{}", nix_config_dir.display());
    let build_arg = format!("path:{}#nixosConfigurations.{}.config.system.build.kexecTree", nix_config_dir_str, hostname);
    let out_link = output_dir.join("kexecTree");
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

    // Create a tarball for the nixConfig directory.
    let nixconfig_tar = output_dir.join("nixConfig.tar");
    if let Err(e) = create_tarball(&nix_config_dir, "nixConfig", &nixconfig_tar) {
        eprintln!("Failed to create nixConfig.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to create nixConfig.tar"
        }));
    }

    // Create a tarball for kexecTree (resolve symlinks).
    let kexec_tree_real = match fs::canonicalize(&out_link) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Failed to resolve kexecTree symlink: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to resolve kexecTree"
            }));
        }
    };

    let kexec_tar = output_dir.join("kexecTree.tar");
    if let Err(e) = create_tarball(&kexec_tree_real, "kexecTree", &kexec_tar) {
        eprintln!("Failed to create kexecTree.tar: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to create kexecTree.tar"
        }));
    }

    // Remove the original directories.
    if let Err(e) = fs::remove_dir_all(&nix_config_dir) {
        eprintln!("Failed to remove nixConfig directory: {:?}", e);
    }
    if let Err(e) = fs::remove_file(&out_link) {
        eprintln!("Failed to remove kexecTree symlink: {:?}", e);
    }

    // Compute SHA-256 hashes.
    let nix_hash = match compute_sha256(&nixconfig_tar) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("Failed to compute SHA256 for nixConfig.tar: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to compute SHA256 for nixConfig.tar"
            }));
        }
    };

    let kexec_hash = match compute_sha256(&kexec_tar) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("Failed to compute SHA256 for kexecTree.tar: {:?}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "status": "error",
                "message": "Failed to compute SHA256 for kexecTree.tar"
            }));
        }
    };

    // Write the hashes to verify.txt.
    let verify_txt = format!("nixConfig.tar {}\nkexecTree.tar {}\n", nix_hash, kexec_hash);
    let verify_path = output_dir.join("verify.txt");
    if let Err(e) = fs::write(&verify_path, verify_txt.as_bytes()) {
        eprintln!("Failed to write verify.txt: {:?}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "status": "error",
            "message": "Failed to write verify.txt"
        }));
    }

    // Return download links.
    let download_links = vec![
        format!("{}/result/{}", data.base_url, "nixConfig.tar"),
        format!("{}/result/{}", data.base_url, "kexecTree.tar"),
        format!("{}/result/{}", data.base_url, "verify.txt"),
    ];

    HttpResponse::Ok().json(serde_json::json!({
        "download_links": download_links,
        "status": "ok"
    }))
}

/// Create a tar archive from a source directory.
fn create_tarball<P: AsRef<Path>, Q: AsRef<Path>>(source: P, dir_name: &str, tar_path: Q) -> std::io::Result<()> {
    let tar_file = fs::File::create(tar_path)?;
    let mut builder = Builder::new(tar_file);
    builder.append_dir_all(dir_name, source)?;
    builder.finish()?;
    Ok(())
}

/// Compute the SHA-256 hash of a file.
fn compute_sha256<P: AsRef<Path>>(path: P) -> std::io::Result<String> {
    let file = fs::File::open(path)?;
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 1024];
    loop {
        let n = reader.read(&mut buffer)?;
        if n == 0 { break; }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
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
    let base_url = format!("http://{}:{}", addr, port);

    println!("Running on: {}", base_url);
    let temp_dir = TempDir::new().expect("Failed to create temporary directory");
    println!("Using temporary directory: {}", temp_dir.path().display());

    let app_state = web::Data::new(AppState { temp_dir, base_url });

    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .wrap(Cors::permissive())
            .route("/", web::get().to(health_check))
            .route("/nixosConfig", web::post().to(nixos_config))
            .service(
                Files::new("/result", app_state.temp_dir.path())
                    .prefer_utf8(true)
                    .show_files_listing(),
            )
    })
    .bind(format!("{}:{}", addr, port))?
    .run()
    .await
}
