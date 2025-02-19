use serde_json::Error;
use backend::schema_types::Config;

#[test]
fn test_invalid_json() {
    // In this JSON, the "ssh.authorizedKeys" array is missing a closing bracket.
    let json_str = r#"
    {
        "localization": {
            "hostname": "example"
        },
        "ssh": {
            "authorizedKeys": ["ssh-rsa AAAAB3Nza..."
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail for invalid JSON syntax"
    );
}

#[test]
fn test_invalid_types() {
    // In this JSON, the "hostname" field is a number instead of a string.
    let json_str = r#"
    {
        "localization": {
            "hostname": 1234
        },
        "ssh": {
            "authorizedKeys": ["ssh-rsa AAAAB3Nza..."]
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail for invalid type in 'hostname'"
    );
}

#[test]
fn test_unknown_fields() {
    // This JSON contains an extra field "extra" in configuration root,
    // which should be rejected due to #[serde(deny_unknown_fields)].
    let json_str = r#"
    {
        "localization": {
            "hostname": "example"
        },
        "ssh": {
            "authorizedKeys": ["ssh-rsa AAAAB3Nza..."]
        },
        "extra": {
          "unexpected": true
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail due to unknown block 'extra'"
    );
}

#[test]
fn test_unknown_nested_fields() {
    // This JSON contains an extra field "extra" in the localization block,
    // which should be rejected due to #[serde(deny_unknown_fields)].
    let json_str = r#"
    {
        "localization": {
            "hostname": "example",
            "extra": "unexpected"
        },
        "ssh": {
            "authorizedKeys": ["ssh-rsa AAAAB3Nza..."]
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail due to unknown field 'extra'"
    );
}


#[test]
fn test_missing_required_fields() {
    // The "ssh" field is required but missing in this JSON.
    let json_str = r#"
    {
        "localization": {
            "hostname": "example"
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail when a required field (ssh) is missing"
    );
}

#[test]
fn test_missing_nested_required_fields() {
    // The "ssh.authorizedKeys" field is required but missing in this JSON.
    let json_str = r#"
    {
        "localization": {
            "hostname": "example"
        },
        "ssh": {
            "privateKeyFile": "/var/mnt/secrets/ssh/id_ed25519"
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_err(),
        "Deserialization should fail when a required field (authorizedKeys) is missing"
    );
}

#[test]
fn test_valid_config() {
    // A minimal valid configuration containing the required fields.
    let json_str = r#"
    {
        "localization": {
            "hostname": "example"
        },
        "ssh": {
            "authorizedKeys": ["ssh-rsa AAAAB3Nza..."]
        }
    }
    "#;
    let config: Result<Config, Error> = serde_json::from_str(json_str);
    assert!(
        config.is_ok(),
        "Deserialization should succeed with a minimal valid configuration"
    );
}

