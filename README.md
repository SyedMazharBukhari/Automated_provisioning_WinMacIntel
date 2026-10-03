# Automated Vagrant Provisioning (Windows / Intel Mac)

This directory provisions a five-VM VProfile environment with Vagrant and VirtualBox. The VMs provide the database, cache, message broker, application server, and web proxy. The `Vagrantfile` is the source of truth for machine definitions and provisioning.

> This setup targets Windows and Intel-based Macs. It uses VirtualBox and x86-64 Vagrant boxes; it is not configured for Apple Silicon.

## Prerequisites

- A supported Windows or Intel Mac host with hardware virtualization enabled.
- Oracle VirtualBox installed.
- Vagrant installed and available on your `PATH`.
- Enough host memory for the configured guest allocations (about 6.6 GiB total), plus memory for the host OS. 12 GiB or more of host RAM is recommended.
- Internet access so Vagrant can download boxes and the provisioning scripts can download packages and application sources.
- The Vagrant Host Manager plugin:

  ```sh
  vagrant plugin install vagrant-hostmanager
  ```

  Host Manager updates the host's `hosts` file for the VM hostnames and may request administrator privileges.

Make sure the VirtualBox host-only network can use the `192.168.56.0/24` subnet. The VMs use fixed addresses in this range.

## Start the environment

Open PowerShell, Command Prompt, or a terminal and change to this directory (the directory containing `Vagrantfile`). Start all five machines with:

```sh
vagrant up
```

The first run downloads the VM boxes, creates the machines, and runs each configured shell provisioner. Provisioning takes time and requires internet access. Subsequent `vagrant up` runs start existing machines; to rerun provisioning after changing a script, use:

```sh
vagrant provision
```

To start only selected machines, pass their names:

```sh
vagrant up db01 mc01 rmq01 app01 web01
```

Check machine state and connect to a VM over SSH with:

```sh
vagrant status
vagrant ssh app01
```

Useful lifecycle commands:

```sh
vagrant halt       # Shut down all VMs
vagrant resume     # Resume suspended VMs
vagrant reload     # Restart VMs
vagrant reload --provision  # Restart and rerun provisioning
```

`vagrant destroy` removes the VMs and their local guest disks, including data stored inside them. Run it only when you intend to rebuild from scratch.

## Machines and services

| Machine | Private IP | Guest OS | Memory | Role |
| --- | --- | --- | ---: | --- |
| `web01` | `192.168.56.11` | Ubuntu Jammy | 800 MB | Nginx reverse proxy |
| `app01` | `192.168.56.12` | CentOS Stream 9 | 800 MB | Java/Tomcat application server; builds and deploys the VProfile application |
| `mc01` | `192.168.56.14` | CentOS Stream 9 | 1,024 MB | Memcached |
| `db01` | `192.168.56.15` | CentOS Stream 9 | 2,048 MB | MariaDB database and initial `accounts` data |
| `rmq01` | `192.168.56.16` | CentOS Stream 9 | 2,048 MB | RabbitMQ message broker |

The Vagrantfile configures private networking and Host Manager-managed hostnames. Nginx on `web01` listens on port 80 and proxies requests to Tomcat on `app01`.

After provisioning completes, open the application through the host's browser:

- `http://192.168.56.11/` — through Nginx (recommended)
- `http://192.168.56.12:8080/` — directly through Tomcat

These addresses are reachable from the host over the VirtualBox host-only network. The provisioning scripts also configure the database, Memcached, and RabbitMQ for the application network.

## What is in this directory?

- `Vagrantfile` — defines all five VMs, their boxes, hostnames, private IPs, memory, and provisioner scripts.
- `mysql.sh` — installs and configures MariaDB, creates the `accounts` database, imports the VProfile database dump, and configures database access.
- `memcache.sh` — installs and configures Memcached and its firewall rule.
- `rabbitmq.sh` — configures RabbitMQ repositories, installs the broker, creates the application user, and opens its service port.
- `tomcat.sh` — installs Java and Tomcat, builds the application from the `local` branch, and deploys it to Tomcat.
- `nginx.sh` — installs Nginx and configures the reverse proxy to `app01`.
- `application.properties` — application configuration reference; the current Tomcat provisioner does not copy this file into the deployed application.
- `backend.sh` and `tomcat_ubuntu.sh` — additional/older helper scripts. They are **not** invoked by the current Vagrantfile.

The provisioned database and broker use example credentials defined in the scripts. Treat them as development-only; change them before using this setup with sensitive data or outside a trusted lab network.

## Fixes from the original cloned version

The original configuration had startup/provisioning issues on the CentOS Stream 9 and Ubuntu guests. This version includes the following changes:

- Increased VM memory where the original allocations were too small for the provisioned services: MariaDB and RabbitMQ now have 2,048 MB each, and Memcached has 1,024 MB. The Nginx GUI setting is disabled for headless operation.
- Added a persistent 1 GiB swap file in the MariaDB, Memcached, and RabbitMQ provisioning scripts to give existing VMs additional memory headroom. Existing VMs may need a restart before VirtualBox applies their updated memory allocation.
- Updated the RabbitMQ setup to use RabbitMQ's EL 9 repositories and signing keys instead of the old CentOS RabbitMQ repository/package instructions. It waits for the service, creates or updates the expected application user, assigns permissions, and configures the firewall.
- Reworked Memcached startup using a systemd override for TCP listening on the VM network, disabled its unused UDP listener, and limited the firewall rule to the private subnet.
- Reworked the Nginx setup to write its site configuration to the correct location, proxy to `192.168.56.12` explicitly rather than relying on guest hostname resolution, validate the configuration, and restart the service.
- Made the updated database, cache, broker, and Nginx scripts fail when a command fails, so provisioning errors are reported instead of being silently followed by later steps.

The Vagrantfile and provisioning scripts are intended for a development/lab environment, not production deployment.
