# LEMP Stack & WordPress Deployment with Ansible

Automated, modular Ansible playbook for deploying a high-performance **LEMP Stack (Linux, Nginx, MariaDB, PHP-FPM)** and an optimized **WordPress** installation on Debian/Ubuntu-based servers.

---

## 📋 Features

- **MariaDB Role (`roles/mariadb`)**:
  - Installs MariaDB server and Python MySQL bindings (`python3-pymysql`).
  - Ensures the service is enabled and running.
  - Hardens database security (removes anonymous users and test database).
  - Automatically provisions the WordPress database, dedicated application user, and grant privileges.

- **PHP-FPM Role (`roles/php`)**:
  - Installs PHP-FPM along with essential WordPress extensions (`cli`, `common`, `mysql`, `curl`, `gd`, `intl`, `mbstring`, `soap`, `xml`, `zip`, `imagick`, `bcmath`).
  - Configurable for native distro packages (e.g. PHP 8.5 on Ubuntu 26.04) or external PPA (`ppa:ondrej/php`).
  - Automatically manages and reloads the PHP-FPM service.

- **Nginx Role (`roles/nginx`)**:
  - Installs and enables Nginx.
  - Disables default virtual host site.
  - Deploys a customized virtual host for WordPress using Unix socket connection to PHP-FPM.
  - Configures clean URL routing (`try_files`), security headers/rules (`.ht*` protection), and static asset caching.

- **WordPress Role (`roles/wordpress`)**:
  - Automatically downloads and extracts the latest official WordPress release.
  - Creates the web root directory with proper user/group permissions (`www-data`).
  - Dynamically renders `wp-config.php` with database credentials, table prefix, and unique security keys/salts.
  - Ensures correct file ownership and permissions across the entire document root.

---

## 📁 Project Structure

```text
LEMP-Deployment/
├── ansible.cfg                 # Ansible configuration (inventory path, forks)
├── group_vars/
│   └── all.yaml                # Global variables shared across roles
├── host_vars/
│   └── anyhost.yaml            # Host-specific overrides (optional)
├── inventory/
│   └── hosts.yml               # Target servers inventory definition
├── main_playbook.yaml          # Main playbook execution entry point
├── roles/
│   ├── mariadb/
│   │   ├── defaults/main.yml   # Default variables for MariaDB
│   │   └── tasks/main.yml      # MariaDB provisioning tasks
│   ├── nginx/
│   │   ├── defaults/main.yml   # Default variables for Nginx
│   │   ├── handlers/main.yml   # Nginx reload/restart handlers
│   │   ├── tasks/main.yml      # Nginx provisioning tasks
│   │   └── templates/
│   │       └── wordpress.conf.j2 # Nginx VirtualHost Jinja2 template
│   ├── php/
│   │   ├── defaults/main.yml   # Default variables for PHP-FPM
│   │   ├── handlers/main.yml   # PHP-FPM restart handlers
│   │   └── tasks/main.yml      # PHP-FPM provisioning tasks
│   └── wordpress/
│       ├── defaults/main.yml   # Default variables for WordPress
│       ├── tasks/main.yml      # WordPress installation tasks
│       └── templates/
│           └── wp-config.php.j2 # wp-config.php Jinja2 template
└── README.md
```

---

## ⚙️ Prerequisites

### Control Node (Your Machine)
- **Ansible** (`ansible-core` >= 2.15)
- **SSH Client**
- **`sshpass`** (optional, required only if using password-based SSH authentication instead of SSH keys):
  - *Arch / CachyOS*: `sudo pacman -S sshpass`
  - *Ubuntu / Debian*: `sudo apt install sshpass`
  - *Fedora / RHEL*: `sudo dnf install sshpass`

### Managed Target Node(s)
- **Operating System**: Ubuntu 22.04 / 24.04 / 26.04 or Debian 11 / 12.
- **SSH access** with a user that has `sudo` privileges.
- *Recommended*: Passwordless sudo configured for the Ansible user (`user ALL=(ALL) NOPASSWD:ALL`) in `/etc/sudoers.d/ansible_user`.

---

## 🚀 Quick Start

### 1. Configure the Inventory
Edit [`inventory/hosts.yml`](inventory/hosts.yml) with your target server IP, SSH username, and credentials:

```yaml
all:
  hosts:
    nodo1:
      ansible_host: 192.168.1.134
      ansible_user: user
      ansible_password: your_ssh_password          # Or use SSH keys
      ansible_become_password: your_sudo_password  # If sudo requires password
```

### 2. Customize Application Variables
Review and modify global variables in [`group_vars/all.yaml`](group_vars/all.yaml):

```yaml
# Domain and Web Root
server_name: "_"
app_dir: /var/www/wordpress

# Nginx
nginx_port: 80

# PHP Version (e.g. 8.5 for Ubuntu 26.04, 8.3 for Ubuntu 24.04)
php_version: "8.5"
php_fpm_user: www-data
php_fpm_group: www-data

# MariaDB Credentials
db_name: wordpress_db
db_user: wp_user
db_password: strong_database_password_here
db_host: localhost

# WordPress Table Prefix
wp_table_prefix: "wp_"
```

### 3. Verify Connection
Test connectivity to your managed hosts:

```bash
ansible all -i inventory/hosts.yml -m ping
```

### 4. Run the Playbook
Deploy the full LEMP stack and WordPress by executing:

```bash
ansible-playbook main_playbook.yaml
```

Once completed, open your browser and navigate to `http://<TARGET_HOST_IP>` (e.g., `http://192.168.1.134`) to finish the WordPress web installer.

---

## 🔧 Variables & Role Customization

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `server_name` | `"_"` | Domain name or IP for Nginx server block (`server_name`). |
| `app_dir` | `/var/www/wordpress` | Directory path where WordPress is extracted and served. |
| `nginx_port` | `80` | HTTP listening port for Nginx. |
| `php_version` | `"8.5"` | PHP major.minor version used for packages and socket path. |
| `php_use_ppa` | `false` | Set `true` to enable Ondřej Surý PPA on supported Ubuntu versions. |
| `db_name` | `wordpress_db` | Name of the MariaDB database for WordPress. |
| `db_user` | `wp_user` | Database user created with permissions on `db_name`. |
| `db_password` | `wp_secure_password_123` | Password for the database user. |
| `db_host` | `localhost` | Database host (defaults to local socket/connection). |
| `wp_table_prefix`| `"wp_"` | Database table prefix for WordPress tables. |

---

## 🛠️ Troubleshooting & Notes

- **Privilege Escalation on Modern Ubuntu (26.04+ / `sudo-rs`)**:
  Ubuntu 26.04 utilizes `sudo-rs` by default. To ensure reliable non-interactive privilege escalation, configure `NOPASSWD` for the Ansible user on the remote host:
  ```bash
  echo "user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible_user
  sudo chmod 0440 /etc/sudoers.d/ansible_user
  ```

- **SSH Keys Authentication**:
  For maximum security and performance, avoid storing plain-text passwords in inventory files. Deploy your SSH public key to the remote host:
  ```bash
  ssh-copy-id user@<SERVER_IP>
  ```

---

## 📄 License

This project is open-source and licensed under the terms of the [MIT License](LICENSE).
