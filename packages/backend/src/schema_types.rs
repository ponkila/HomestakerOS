use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub addons: Option<Addons>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub consensus: Option<Consensus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub execution: Option<Execution>,
    pub localization: Localization,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mounts: Option<HashMap<String, Mount>>,
    pub ssh: SSH,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vpn: Option<Vpn>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Addons {
    #[serde(rename = "mev-boost", skip_serializing_if = "Option::is_none")]
    pub mev_boost: Option<MevBoost>,
    #[serde(rename = "ssv-node", skip_serializing_if = "Option::is_none")]
    pub ssv_node: Option<SsvNode>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MevBoost {
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SsvNode {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    #[serde(rename = "privateKeyFile", skip_serializing_if = "Option::is_none")]
    pub private_key_file: Option<String>,
    #[serde(
        rename = "privateKeyPasswordFile",
        skip_serializing_if = "Option::is_none"
    )]
    pub private_key_password_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Consensus {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lighthouse: Option<Lighthouse>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nimbus: Option<Nimbus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prysm: Option<Prysm>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub teku: Option<Teku>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Lighthouse {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "execEndpoint")]
    pub exec_endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub slasher: Option<LighthouseSlasher>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LighthouseSlasher {
    pub enable: bool,
    #[serde(rename = "historyLength")]
    pub history_length: i32,
    #[serde(rename = "maxDatabaseSize")]
    pub max_database_size: i32,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Nimbus {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "execEndpoint")]
    pub exec_endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Prysm {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "execEndpoint")]
    pub exec_endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub slasher: Option<PrysmSlasher>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PrysmSlasher {
    pub enable: bool,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Teku {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "execEndpoint")]
    pub exec_endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Execution {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub besu: Option<Besu>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub erigon: Option<Erigon>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub geth: Option<Geth>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nethermind: Option<Nethermind>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Besu {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Erigon {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Geth {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Nethermind {
    #[serde(rename = "dataDir")]
    pub data_dir: String,
    pub enable: bool,
    pub endpoint: String,
    #[serde(rename = "jwtSecretFile", skip_serializing_if = "Option::is_none")]
    pub jwt_secret_file: Option<String>,
    #[serde(rename = "extraOptions", skip_serializing_if = "Option::is_none")]
    pub extra_options: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Localization {
    pub hostname: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub timezone: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Mount {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub enable: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub options: Option<String>,
    #[serde(rename = "type")]
    pub mount_type: String,
    #[serde(rename = "wantedBy", skip_serializing_if = "Option::is_none")]
    pub wanted_by: Option<Vec<String>>,
    pub what: String,
    #[serde(rename = "where")]
    pub mount_point: String,
    // Additional keys:
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wants: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub upholds: Option<Vec<String>>,
    #[serde(rename = "upheldBy", skip_serializing_if = "Option::is_none")]
    pub upheld_by: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub unit_config: Option<String>,
    #[serde(
        rename = "startLimitIntervalSec",
        skip_serializing_if = "Option::is_none"
    )]
    pub start_limit_interval_sec: Option<u64>,
    #[serde(rename = "startLimitBurst", skip_serializing_if = "Option::is_none")]
    pub start_limit_burst: Option<u64>,
    #[serde(rename = "restartTriggers", skip_serializing_if = "Option::is_none")]
    pub restart_triggers: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub requisite: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub requires: Option<Vec<String>>,
    #[serde(rename = "requiredBy", skip_serializing_if = "Option::is_none")]
    pub required_by: Option<Vec<String>>,
    #[serde(rename = "reloadTriggers", skip_serializing_if = "Option::is_none")]
    pub reload_triggers: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub part_of: Option<Vec<String>>,
    #[serde(rename = "overrideStrategy", skip_serializing_if = "Option::is_none")]
    pub override_strategy: Option<String>,
    #[serde(rename = "onSuccess", skip_serializing_if = "Option::is_none")]
    pub on_success: Option<Vec<String>>,
    #[serde(rename = "onFailure", skip_serializing_if = "Option::is_none")]
    pub on_failure: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "mountConfig", skip_serializing_if = "Option::is_none")]
    pub mount_config: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub documentation: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub conflicts: Option<Vec<String>>,
    #[serde(rename = "bindsTo", skip_serializing_if = "Option::is_none")]
    pub binds_to: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub before: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub aliases: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub after: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SSH {
    #[serde(rename = "authorizedKeys")]
    pub authorized_keys: Vec<String>,
    #[serde(rename = "privateKeyFile", skip_serializing_if = "Option::is_none")]
    pub private_key_file: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Vpn {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wireguard: Option<Wireguard>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Wireguard {
    #[serde(rename = "configFile")]
    pub config_file: String,
    pub enable: bool,
}
