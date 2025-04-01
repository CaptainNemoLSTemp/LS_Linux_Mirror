#!/usr/bin/env python3
import os
import sys
import yaml
import subprocess
from pathlib import Path


def generate_ssh_key(output_path, bits=4096, comment=None):
    """Generate an SSH key pair and save to the specified path."""
    cmd = ["ssh-keygen", "-t", "rsa", "-b", str(bits), "-f", output_path, "-N", ""]
    
    if comment:
        cmd.extend(["-C", comment])
    
    print(f"Generating SSH key: {output_path}")
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)

def process_ansible_inventory(inventory_path, key_id):
    """
    Read Ansible inventory YAML file and generate SSH keys for all groups.
    - One key per group with format keyID where ID is the command-line option
    - One key per host with the full host name
    
    Args:
        inventory_path: Path to the Ansible inventory YAML file
        key_id: ID number for the keys (from command-line)
    """
    # Check if inventory file exists
    if not os.path.exists(inventory_path):
        print(f"Error: Inventory file '{inventory_path}' not found")
        sys.exit(1)
    
    # Read and parse YAML file
    with open(inventory_path, 'r') as f:
        try:
            inventory = yaml.safe_load(f)
        except yaml.YAMLError as e:
            print(f"Error parsing YAML file: {e}")
            sys.exit(1)
    
    # Filter to only process groups with hosts defined
    valid_groups = []
    for group_name, group_data in inventory.items():
        if isinstance(group_data, dict) and 'hosts' in group_data:
            valid_groups.append(group_name)
    
    if not valid_groups:
        print("No valid groups with hosts found in inventory")
        sys.exit(1)
    
    print(f"Found {len(valid_groups)} valid groups: {', '.join(valid_groups)}")
    
    # Process each group in the inventory
    for group_index, group_name in enumerate(valid_groups, 1):
        group_data = inventory[group_name]
        
        # Create group directory
        group_dir = Path(f"keys/{group_name}")
        group_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate 1 key for the group with the specified key_id
        print(f"\nGenerating key for group '{group_name}' (key{key_id}):")
        key_name = f"key{key_id}"
        key_path = group_dir / key_name
        generate_ssh_key(key_path, comment=f"key {key_id}")
        
        # Process hosts in the group
        host_count = len(group_data['hosts'])
        print(f"Generating keys for {host_count} hosts in group '{group_name}':")
        
        for host_name, host_info in group_data['hosts'].items():
            # Handle hosts with ranges like [01:20]
            if '[' in host_name and ':' in host_name:
                base_name = host_name.split('[')[0]
                range_part = host_name.split('[')[1].split(']')[0]
                start, end = map(int, range_part.split(':'))
                
                # Generate for each host in the range
                for item in range(start, end + 1):
                    # Format with leading zeros if the original had them
                    if range_part.startswith('0'):
                        item_str = f"{item:0{len(str(start))}d}"
                    else:
                        item_str = str(item)
                    
                    expanded_host_name = f"{base_name}{item_str}"
                    host_dir = group_dir / expanded_host_name
                    host_dir.mkdir(exist_ok=True)
                    
                    # Generate 1 key for the host with the full host name
                    key_path = host_dir / f"{expanded_host_name}"
                    generate_ssh_key(key_path, comment=f"{expanded_host_name} key")
            else:
                # Regular host without range
                host_dir = group_dir / host_name
                host_dir.mkdir(exist_ok=True)
                
                # Generate 1 key for the host with the full host name
                key_path = host_dir / f"{host_name}"
                generate_ssh_key(key_path, comment=f"{host_name} key")

def main():
    if len(sys.argv) != 3:
        print("Usage: ./ansible_ssh_key_generator.py <inventory_file.yml> <key_id>")
        print("Example: ./ansible_ssh_key_generator.py inventory.yml 1")
        sys.exit(1)
    
    inventory_path = sys.argv[1]
    
    # Validate key_id is a number
    try:
        key_id = int(sys.argv[2])
    except ValueError:
        print("Error: key_id must be a number")
        sys.exit(1)
    
    print(f"Reading inventory from: {inventory_path}")
    print(f"Using key ID: {key_id}")
    
    process_ansible_inventory(inventory_path, key_id)
    print("\nSSH key generation complete!")

if __name__ == "__main__":
    main()