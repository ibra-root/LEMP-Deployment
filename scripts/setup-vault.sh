#!/usr/bin/env bash
#
# Generate local deployment secrets:
#   - group_vars/all/vault.yml  (encrypted with Ansible Vault)
#   - .vault_pass               (passphrase, mode 0600, gitignored)
#
# Usage: ./scripts/setup-vault.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

VAULT_FILE="$REPO_ROOT/group_vars/all/vault.yml"
VAULT_PASS_FILE="$REPO_ROOT/.vault_pass"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v ansible-vault >/dev/null 2>&1 || die "ansible-vault is not installed."
command -v openssl >/dev/null 2>&1 || die "openssl is not installed."
[ -f "$REPO_ROOT/group_vars/all/vars.yml" ] || die "group_vars/all/vars.yml not found. Is this the right repository?"

if [ -e "$VAULT_FILE" ]; then
  die "group_vars/all/vault.yml already exists. Remove or move it to regenerate."
fi

mkdir -p "$REPO_ROOT/group_vars/all"

# Vault passphrase
if [ -s "$VAULT_PASS_FILE" ]; then
  echo "Using the existing passphrase in .vault_pass"
else
  echo
  echo "Vault passphrase (Enter to generate a random one):"
  read -rsp "  Passphrase: " VAULT_PASS
  echo
  if [ -z "$VAULT_PASS" ]; then
    VAULT_PASS="$(openssl rand -base64 48 | tr -d '\n')"
    echo "  Generated automatically."
  else
    read -rsp "  Repeat passphrase: " VAULT_PASS_CONFIRM
    echo
    [ "$VAULT_PASS" = "$VAULT_PASS_CONFIRM" ] || die "Passphrases do not match."
  fi

  umask 077
  printf '%s\n' "$VAULT_PASS" > "$VAULT_PASS_FILE"
  chmod 600 "$VAULT_PASS_FILE"
  echo "  Saved to .vault_pass (gitignored). Back it up."
fi

# MariaDB password
DB_PASS=""
echo
echo "MariaDB password for wp_user (Enter to generate a random one):"
while true; do
  read -rsp "  Password: " DB_PASS
  echo
  if [ -z "$DB_PASS" ]; then
    DB_PASS="$(openssl rand -base64 36 | tr -d '\n')"
    echo "  Generated automatically."
    break
  fi
  read -rsp "  Repeat password: " DB_PASS_CONFIRM
  echo
  if [ "$DB_PASS" = "$DB_PASS_CONFIRM" ]; then
    break
  fi
  echo "  Passwords do not match. Try again."
done

# WordPress keys and salts
WP_VALUES=()
for _ in $(seq 1 8); do
  WP_VALUES+=("$(openssl rand -base64 48 | tr -d '\n')")
done

yaml_quote() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
}

TMP_FILE="$(mktemp "$REPO_ROOT/group_vars/all/.vault.XXXXXX")"
cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

{
  echo "---"
  printf 'vault_db_password: %s\n' "$(yaml_quote "$DB_PASS")"
  printf 'vault_wp_auth_key: %s\n' "$(yaml_quote "${WP_VALUES[0]}")"
  printf 'vault_wp_secure_auth_key: %s\n' "$(yaml_quote "${WP_VALUES[1]}")"
  printf 'vault_wp_logged_in_key: %s\n' "$(yaml_quote "${WP_VALUES[2]}")"
  printf 'vault_wp_nonce_key: %s\n' "$(yaml_quote "${WP_VALUES[3]}")"
  printf 'vault_wp_auth_salt: %s\n' "$(yaml_quote "${WP_VALUES[4]}")"
  printf 'vault_wp_secure_auth_salt: %s\n' "$(yaml_quote "${WP_VALUES[5]}")"
  printf 'vault_wp_logged_in_salt: %s\n' "$(yaml_quote "${WP_VALUES[6]}")"
  printf 'vault_wp_nonce_salt: %s\n' "$(yaml_quote "${WP_VALUES[7]}")"
} > "$TMP_FILE"

ansible-vault encrypt \
  --vault-password-file "$VAULT_PASS_FILE" \
  --encrypt-vault-id default \
  --output "$VAULT_FILE" \
  "$TMP_FILE" >/dev/null

# Verify decryption
ansible-vault view --vault-password-file "$VAULT_PASS_FILE" "$VAULT_FILE" >/dev/null

echo
echo "Done. Created:"
echo "  - group_vars/all/vault.yml  (encrypted, gitignored)"
echo "  - .vault_pass               (0600, gitignored)"
echo
echo "Next steps:"
echo "  1. Set the server IP/user in inventory/hosts.yml."
echo "  2. ansible all -m ping                     # check connectivity"
echo "  3. ansible-playbook main_playbook.yaml     # run the deployment"
