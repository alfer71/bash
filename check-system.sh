#!/bin/bash

# List of servers
servers=("172.28.40.18" "172.28.40.38" "172.28.40.43")

# Define output directory
output_dir="reports"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# SSH credentials
username="afernandez"
ssh_key_path="~/.ssh/id_rsa"  # Update with your SSH private key path

# Loop through each server
for server in "${servers[@]}"; do
    echo "Running script on $server..."

    # Define output file for each server
    output_file="${output_dir}/${server}_system_report.txt"

    # SSH into the server and run commands
    ssh "$server" bash << 'EOF'
        # Get hostname and IP address
        hostname=$(hostname)
        ip_address=$(hostname -I | awk '{print $1}')

        # Check uptime
        uptime_info=$(uptime -p)

        # Check processors
        processors=$(nproc)

        # Check memory
        memory=$(free -h | grep Mem | awk '{print $2}')

        # Check local filesystems
        local_filesystems=$(df -h | grep -vE 'tmpfs|devtmpfs|nfs|cifs')

        # Check NFS or CIFS
        nfs_cifs=$(df -h | grep -E 'nfs|cifs')

        # Check firewall
        firewall_active=$(systemctl is-active firewalld)
        if [[ "$firewall_active" == "active" ]]; then
            firewall_rules=$(sudo firewall-cmd --list-all)
            echo "$firewall_rules" > firewall_rules.txt
        fi

        # Check iptables
        iptables_active=$(systemctl is-active iptables)
        if [[ "$iptables_active" == "active" ]]; then
            iptables_rules=$(sudo iptables -S)
            echo "$iptables_rules" > iptables_rules.txt
        fi

        # Display fstab content
        fstab_content=$(cat /etc/fstab)

        # Display passwd content
        passwd_content=$(cat /etc/passwd)

        # List crontab jobs
        crontab_jobs=$(crontab -l)

        # Check active services
        active_services=$(systemctl list-units --type=service --state=active)

        # Check top 7 memory consuming processes
        top_processes=$(ps aux --sort=-%mem | head -n 8)

        # Check last 7 users
        last_users=$(last -n 7)

        # Check system patch date
        patch_date=$(rpm -q --last kernel | head -n 1)

        # List packages updated last time system was patched
        updated_packages=$(rpm -qa --last | grep "$(echo "$patch_date" | awk '{print $3, $4, $5}')")

        # Create the output file with formatted content
        {
            echo "Hostname: $hostname"
            echo "IP Address: $ip_address"
            echo "Uptime: $uptime_info"
            echo "Processors: $processors"
            echo "Memory: $memory"
            echo "Local Filesystems:"
            echo "$local_filesystems"
            echo "NFS or CIFS Filesystems:"
            echo "$nfs_cifs"
            echo "Firewall Active: $firewall_active"
            [[ "$firewall_active" == "active" ]] && echo "Firewall rules saved to firewall_rules.txt"
            echo "iptables Active: $iptables_active"
            [[ "$iptables_active" == "active" ]] && echo "iptables rules saved to iptables_rules.txt"
            echo "fstab Content:"
            echo "$fstab_content"
            echo "passwd Content:"
            echo "$passwd_content"
            echo "Crontab Jobs:"
            echo "$crontab_jobs"
            echo "Active Services:"
            echo "$active_services"
            echo "Top 7 Memory Consuming Processes:"
            echo "$top_processes"
            echo "Last 7 Users:"
            echo "$last_users"
            echo "System Last Patched On: $patch_date"
            echo "Updated Packages Last Patch:"
            echo "$updated_packages"
        } > "$output_file"

EOF
done

# Send the reports to Slack
# Note: Replace YOUR_SLACK_WEBHOOK_URL with your actual Slack webhook URL
for server in "${servers[@]}"; do
    output_file="${output_dir}/${server}_system_report.txt"
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$(cat $output_file)\"}" https://hooks.slack.com/services/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
done
