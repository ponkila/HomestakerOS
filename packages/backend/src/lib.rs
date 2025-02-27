pub mod schema_types;
pub mod workspace;

use sha2::{Digest, Sha256};
use std::fs;
use std::io::{BufReader, Read, Write};
use std::path::Path;
use std::process::{Command as StdCommand, Stdio};
use tar::Builder;

/// Runs the `json2nix` command by piping in the JSON string and returns the command's stdout.
pub fn run_json2nix(json_str: &str) -> Result<String, String> {
    let mut child = StdCommand::new("json2nix")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn json2nix process: {:?}", e))?;

    {
        let stdin = child
            .stdin
            .as_mut()
            .ok_or_else(|| "Failed to open stdin for json2nix".to_string())?;
        stdin
            .write_all(json_str.as_bytes())
            .map_err(|e| format!("Failed to write to stdin of json2nix: {:?}", e))?;
    }
    let output = child
        .wait_with_output()
        .map_err(|e| format!("Command execution failed: {:?}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(stderr);
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Writes the default.nix file with the provided json2nix output.
pub fn write_default_nix(hostname_dir: &Path, json2nix_output: &str) -> std::io::Result<()> {
    let nix_boilerplate = format!(
        "{{ pkgs, lib, config, ... }}: {{ homestakeros = {}; }}",
        json2nix_output
    );
    let default_nix_path = hostname_dir.join("default.nix");
    fs::write(default_nix_path, nix_boilerplate.as_bytes())
}

/// Runs the `nix build` command and returns an error string if it fails.
pub fn run_nix_build(nix_config_dir: &Path, hostname: &str, out_link: &Path) -> Result<(), String> {
    let nix_config_dir_str = format!("{}", nix_config_dir.display());
    let build_arg = format!(
        "path:{}#nixosConfigurations.{}.config.system.build.kexecTree",
        nix_config_dir_str, hostname
    );
    let output = StdCommand::new("nix")
        .arg("build")
        .arg(build_arg)
        .arg("--out-link")
        .arg(out_link)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("Failed to execute nix build: {:?}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(stderr);
    }
    println!(
        "Nix build stdout: {}",
        String::from_utf8_lossy(&output.stdout)
    );
    println!(
        "Nix build stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(())
}

/// Create a tar archive from a source directory.
pub fn create_tarball<P: AsRef<Path>, Q: AsRef<Path>>(
    source: P,
    dir_name: &str,
    tar_path: Q,
) -> std::io::Result<()> {
    let tar_file = fs::File::create(tar_path)?;
    let mut builder = Builder::new(tar_file);
    builder.append_dir_all(dir_name, source)?;
    builder.finish()?;
    Ok(())
}

/// Compute the SHA-256 hash of a file.
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
