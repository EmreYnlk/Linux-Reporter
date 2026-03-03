# Linux Reporter

**Linux Reporter** is a lightweight Bash-based system monitoring and automated reporting tool for Linux environments. It generates structured system health reports, sends email notifications based on configurable thresholds, and supports scheduled execution via cron jobs.

This project is designed for system administrators and students who need a simple, efficient, and automation-focused server monitoring solution without heavy external dependencies.

# Features

* Disk usage monitoring with configurable threshold alerts
* Memory usage monitoring with threshold detection
* System uptime reporting
* Active user listing
* Automatic report generation with timestamped log files
* Email notification support (including alert mode)
* Cron job creation and removal (default and custom scheduling)
* Automatic old log cleanup
* Interactive terminal menu using dialog
* Automatic execution mode for scheduled tasks

# Project Structure

Linux Reporter/

* rapor5.sh
* config.conf
* .mail_credentials
* logs/

# Requirements

* Linux system (Debian/Ubuntu recommended)
* Bash
* dialog
* ssmtp
* cron

Install required packages (Debian/Ubuntu):

sudo apt update
sudo apt install dialog ssmtp cron -y

# Configuration

## config.conf

Create a file named **config.conf** in the same directory:

DISK_ESIK=80
RAM_ESIK=80
LOG_SAKLAMA_GUN=7

EMAIL_GONDEREN=[your_email@gmail.com](mailto:your_email@gmail.com)
EMAIL_ALICILAR=[recipient1@gmail.com](mailto:recipient1@gmail.com),[recipient2@gmail.com](mailto:recipient2@gmail.com)

## .mail_credentials

Create a file named **.mail_credentials**:

GMAIL_USER=[your_email@gmail.com](mailto:your_email@gmail.com)
GMAIL_PASS=your_app_password

If using Gmail, generate and use an application-specific password.

Set secure permissions:

chmod 600 .mail_credentials

# Usage

Give execution permission:

chmod +x rapor5.sh

Run the script:

./rapor5.sh

or

bash rapor5.sh

# Automatic Mode (Cron Execution)

The script supports automatic execution mode:

./rapor5.sh --auto

In automatic mode, the script:

* Generates a system report
* Sends email notifications
* Deletes logs older than the configured retention period

Example manual cron configuration (run daily at 08:00):

0 8 * * * /path/to/rapor5.sh --auto >> /path/to/logs/cron.log 2>&1

You can also manage cron jobs directly from the interactive menu.

# Log Management

* All reports are stored inside the logs/ directory
* Each report is timestamped
* Logs older than LOG_SAKLAMA_GUN are automatically removed
