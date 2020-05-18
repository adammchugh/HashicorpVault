#!/bin/sh

sudo apt update -y && sudo apt upgrade -y
sudo apt install unzip -y

# sudo ufw enable
# sudo ufw allow 8200/tcp

export VAULT_URL="https://releases.hashicorp.com/vault" VAULT_VERSION="1.3.2"
curl --silent --remote-name "${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
curl --silent --remote-name "${VAULT_URL}/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS"
curl --silent --remote-name "${VAULT_URL}/${VAULT_VERSION}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig"

unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
sudo chown root:root /usr/local/bin/vault
vault --version

vault -autocomplete-install
complete -C /usr/local/bin/vault vault

sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

sudo useradd --system --home /etc/vault.d --shell /bin/false vault

sudo bash -c 'cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF'

sudo mkdir --parents /etc/vault/keys
sudo mkdir --parents /etc/vault.d
sudo touch /etc/vault.d/vault.hcl
sudo chown --recursive vault:vault /etc/vault.d
sudo chmod 640 /etc/vault.d/vault.hcl

sudo openssl req -new -newkey rsa:4096 -x509 -sha512 -days 365 -nodes -out /etc/vault/keys/vault.crt -keyout /etc/vault/keys/vault.key
sudo chmod 400 /etc/vault/keys/vault.key

sudo bash -c 'cat > /etc/vault.d/vault.hcl <<EOF
ui = true
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable = true #Not recommended for production
  #tls_cert_file = "/path/to/fullchain.pem"
  #tls_key_file  = "/path/to/privkey.pem"
  #tls_min_version = tls12
}
storage "file" {
  path  = "/var/lib/vault/data"
}
api_addr  = "http://127.0.0.1:8200"
EOF'

export VAULT_ADDR='http://127.0.0.1:8200'

sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault

vault audit enable
