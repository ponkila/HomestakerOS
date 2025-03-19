pub mod schema_types;
pub mod workspace;

use crate::schema_types::Config;
use actix_web::HttpResponse;
use anyhow::{anyhow, Context, Result};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::{BufReader, Read, Write};
use std::path::Path;
use std::process::{Command as StdCommand, Stdio};
use tar::Builder;

/// Runs the `json2nix` command by piping in the JSON string and returns the command's stdout.
///
/// # Errors
///
/// Returns an error if spawning the process, writing to its stdin, or waiting for its output fails.
pub fn run_json2nix(json_str: &str) -> Result<String> {
    let mut child = StdCommand::new("json2nix")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| "Failed to spawn json2nix process")?;

    {
        let stdin = child
            .stdin
            .as_mut()
            .ok_or_else(|| anyhow!("Failed to open stdin for json2nix"))?;
        stdin
            .write_all(json_str.as_bytes())
            .with_context(|| "Failed to write to stdin of json2nix")?;
    }
    let output = child
        .wait_with_output()
        .with_context(|| "Command execution failed")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(anyhow!(stderr));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Writes the default.nix file with the provided json2nix output.
///
/// # Errors
///
/// Returns an error if writing to the file fails.
pub fn write_default_nix(hostname_dir: &Path, json2nix_output: &str) -> std::io::Result<()> {
    let nix_boilerplate =
        String::from("{ pkgs, lib, config, ... }: { homestakeros = ") + json2nix_output + "; }";
    let default_nix_path = hostname_dir.join("default.nix");
    fs::write(default_nix_path, nix_boilerplate.as_bytes())
}

/// Runs the `nix build` command and returns an error if it fails.
///
/// # Errors
///
/// Returns an error if executing the command fails or if the build does not succeed.
pub fn run_nix_build(
    nix_config_dir: &Path,
    hostname: &str,
    output_dir: &Path,
    whitelist: &[&str],
) -> Result<()> {
    let nix_config_dir_str = nix_config_dir.display().to_string();
    let build_arg = format!(
        "path:{nix_config_dir_str}#nixosConfigurations.{hostname}.config.system.build.kexecTree"
    );
    let out_link_path = nix_config_dir.join("result");

    let output = StdCommand::new("nix")
        .arg("build")
        .arg(build_arg)
        .arg("--out-link")
        .arg(&out_link_path)
        .arg("--extra-experimental-features")
        .arg("nix-command")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .with_context(|| "Failed to execute nix build")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(anyhow!(stderr));
    }
    println!(
        "Nix build stdout: {}",
        String::from_utf8_lossy(&output.stdout)
    );
    println!(
        "Nix build stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Copy whitelisted files from the build output to the output directory
    for entry in fs::read_dir(&out_link_path)
        .with_context(|| format!("Failed to read out_link dir: {out_link_path:?}"))?
    {
        let entry = entry.with_context(|| "Failed to get directory entry")?;
        let path = entry.path();

        if path.is_file() || path.is_symlink() {
            let filename = path
                .file_name()
                .ok_or_else(|| anyhow!("Could not get file_name for {path:?}"))?
                .to_string_lossy()
                .to_string();

            if whitelist.contains(&filename.as_str()) {
                // Resolve the path if it's a symlink
                let real_path = if path.is_symlink() {
                    fs::canonicalize(&path)
                        .with_context(|| format!("Failed to canonicalize {path:?}"))?
                } else {
                    path.clone()
                };

                let dest_file = output_dir.join(&filename);
                fs::copy(&real_path, &dest_file)
                    .with_context(|| format!("Failed to copy {real_path:?} to {dest_file:?}"))?;
            } else {
                println!("Skipping file not in whitelist: {filename}");
            }
        }
    }

    Ok(())
}

/// Computes the SHA-256 hash of a file.
///
/// # Errors
///
/// Returns an error if the file cannot be opened or read.
pub fn compute_sha256<P: AsRef<Path>>(path: P) -> std::io::Result<String> {
    let file = fs::File::open(path)?;
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 1024];
    loop {
        let n = reader.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

/// Processes build artifacts.
///
/// # Errors
///
/// Returns an error if reading the output directory fails or if a directory entry cannot be processed.
pub fn process_artifacts(output_dir: &Path, build_id: &str) -> Result<Vec<Value>> {
    let mut artifacts_info = Vec::new();
    for entry in fs::read_dir(output_dir)
        .with_context(|| format!("Failed to read output_dir: {output_dir:?}"))?
    {
        let entry = entry.with_context(|| "Failed to get directory entry")?;
        let path = entry.path();

        if path.is_file() {
            let filename = path
                .file_name()
                .ok_or_else(|| anyhow!("Could not get file_name for {path:?}"))?
                .to_string_lossy()
                .to_string();

            // Compute SHA256.
            let sha = compute_sha256(&path)
                .with_context(|| format!("Failed to compute SHA256 for {path:?}"))?;
            let download_url = format!("/builds/{build_id}/{filename}");
            artifacts_info.push(json!({
                "file": filename,
                "sha256": sha,
                "download_url": download_url
            }));
        }
    }

    Ok(artifacts_info)
}

/// Logs the error and returns a standardized HTTP error response.
pub fn handle_error<E: std::fmt::Display>(desc: &str, error: E) -> HttpResponse {
    println!("{desc}: {error}");
    HttpResponse::InternalServerError().json(json!({
        "status": "error",
        "message": desc,
        "error": error.to_string()
    }))
}

/// Validates the configuration to ensure it meets required criteria.
///
/// # Errors
///
/// Returns an error if the configuration is invalid for any reason
pub fn validate_config(config: &Config) -> Result<(), String> {
    if config.localization.hostname.trim().is_empty() {
        return Err("The 'localization.hostname' must not be empty".into());
    }
    if config.ssh.authorized_keys.is_empty() {
        return Err("The 'ssh.authorizedKeys' must contain at least one key".into());
    }
    for key in &config.ssh.authorized_keys {
        if key.trim().is_empty() {
            return Err("The 'ssh.authorizedKeys' must not contain an empty key".into());
        }
    }
    Ok(())
}

/// Create a tar archive from a source directory.
///
/// # Errors
///
/// Returns an error if writing to the archive fails.
pub fn create_tarball<P: AsRef<Path>>(
    source: P,
    output_dir: &Path,
    filename: &str,
) -> std::io::Result<()> {
    let tar_path = output_dir.join(filename);
    let tar_file = fs::File::create(tar_path)?;
    let mut builder = Builder::new(tar_file);
    builder.append_dir_all("", source)?;
    builder.finish()?;
    Ok(())
}
