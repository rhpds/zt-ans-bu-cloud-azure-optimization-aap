#!/bin/bash

systemctl stop systemd-tmpfiles-setup.service
systemctl disable systemd-tmpfiles-setup.service

nmcli connection add type ethernet con-name enp2s0 ifname enp2s0 ipv4.addresses 192.168.1.10/24 ipv4.method manual connection.autoconnect yes
nmcli connection up enp2s0
echo "192.168.1.10 control.lab control controller" >> /etc/hosts

########
## install python3 libraries needed for the Cloud Report
dnf install -y python3-pip python3-libsemanage
export THISAAPHOST=$(hostname -A)

# Create a playbook for the user to execute
tee /tmp/setup.yml << EOF
### Automation Controller setup 
###
---
- name: Setup Controller
  hosts: localhost
  connection: local
  collections:
    - ansible.controller

  vars:
    aws_access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') | default('AWS_ACCESS_KEY_ID_NOT_FOUND', true) }}"
    aws_secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') | default('AWS_SECRET_ACCESS_KEY_NOT_FOUND', true) }}"
    aws_default_region: "{{ lookup('env', 'AWS_DEFAULT_REGION') | default('AWS_DEFAULT_REGION_NOT_FOUND', true) }}"
    quay_username: "{{ lookup('env', 'QUAY_USERNAME') | default('QUAY_USERNAME_NOT_FOUND', true) }}"
    quay_password: "{{ lookup('env', 'QUAY_PASSWORD') | default('QUAY_PASSWORD_NOT_FOUND', true) }}"
    azure_subscription: "{{ lookup('env', 'AZURE_SUBSCRIPTION') | default('AZURE_SUBSCRIPTION_NOT_FOUND', true) }}"
    azure_tenant: "{{ lookup('env', 'AZURE_TENANT') | default('AZURE_TENANT_NOT_FOUND', true) }}"
    azure_client_id: "{{ lookup('env', 'AZURE_CLIENT_ID') | default('AZURE_CLIENT_ID_NOT_FOUND', true) }}"
    azure_password: "{{ lookup('env', 'AZURE_PASSWORD') | default('AZURE_PASSWORD_NOT_FOUND', true) }}"
    azure_resourcegroup: "{{ lookup('env', 'AZURE_RESOURCEGROUP') | default('AZURE_RESOURCEGROUP_NOT_FOUND', true) }}"
    username: "admin"
    admin_password: "ansible123!"
    controller_host: "https://localhost"
    thisaaphostfqdn: $THISAAPHOST

  tasks:
    - name: Set base url
      awx.awx.settings:
        name: AWX_COLLECTIONS_ENABLED
        value: "false"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Add azure credential to automation controller
      awx.awx.credential:
        name: azure_credential
        description: Azure Instruqt Credential
        organization: "Default"
        state: present
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
        credential_type: Microsoft Azure Resource Manager
        inputs:
          subscription: "{{ azure_subscription }}"
          secret: "{{ azure_password }}"
          client: "{{ azure_client_id }}"
          tenant: "{{ azure_tenant }}"
          # username: "{{ lookup('env', 'INSTRUQT_AZURE_SUBSCRIPTION_AAPAZURELAB_USERNAME') }}"
          # password: "{{ lookup('env', 'INSTRUQT_AZURE_SUBSCRIPTION_AAPAZURELAB_PASSWORD') }}"
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Add RHEL on Azure credential to automation controller
      awx.awx.credential:
        name: "RHEL on Azure"
        description: "Machine Credential for Azure RHEL instances"
        organization: "Default"
        state: present
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
        credential_type: Machine
        inputs:
          username: "rheluser"
          password: "RedHatAnsible123!"
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Add Windows on Azure credential to automation controller
      awx.awx.credential:
        name: "Windows on Azure"
        description: "Machine Credential for Azure Windows instances"
        organization: "Default"
        state: present
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
        credential_type: Machine
        inputs:
          username: "azureuser"
          password: "RedHatAnsible123!"
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Add EE to the controller instance
      awx.awx.execution_environment:
        name: "Microsoft Azure Execution Environment"
        image: quay.io/aoc/ee-aap-azure-sre
        # image: quay.io/acme_corp/azure_ee
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Add Azure Demos Project project
      awx.awx.project:
        name: "Azure Demos Project"
        description: "This is from github.com/ansible-cloud"
        organization: "Default"
        state: present
        scm_type: git
        scm_url: https://github.com/ansible-cloud/azure-demos
        default_environment: "Microsoft Azure Execution Environment"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Add Product Demos project
      awx.awx.project:
        name: "Product Demos Project"
        description: "This is from github.com/ansible/product-demos"
        organization: "Default"
        state: present
        scm_type: git
        scm_url: https://github.com/ansible/product-demos
        default_environment: "Default execution environment"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Add project
      awx.awx.project:
        name: "Cloud Visibility Project"
        description: "This is from github.com/ansible-cloud"
        organization: "Default"
        state: present
        scm_type: git
        scm_url: https://github.com/ansible-cloud/azure_visibility
        default_environment: "Microsoft Azure Execution Environment"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      register: controller_try
      retries: 5
      until: controller_try is not failed

    - name: Delete native job template
      awx.awx.job_template:
        name: "Demo Job Template"
        state: "absent"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Add ansible-1 host
      awx.awx.host:
        name: "ansible-1"
        inventory: "Demo Inventory"
        state: present
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
        variables:
          note: in production these passwords would be encrypted in vault
          ansible_user: rhel
          ansible_password: ansible123!
          ansible_host: "{{ thisaaphostfqdn }}"

    - name: Create job template
      awx.awx.job_template:
        name: "{{ item.name }}"
        job_type: "run"
        organization: "Default"
        inventory: "Demo Inventory"
        project: "Azure Demos Project"
        extra_vars:
          resource_group_name: "azure-demo"
          region: "eastus"
          vnet_cidr: "10.0.0.0/16"
          subnet_cidr: "10.0.1.0/24"
          vnet_name: "demo_vnet"
          subnet_name: "demo_subnet"
          network_sec_group_name: "demo_sec_group"
          win_vm_name: "WIN-ansible"
          win_vm_name_sa: "winansiblesa9999"
          win_vm_size: "Standard_DS1_v2"
          win_vm_sku: "2022-Datacenter"
          win_public_ip_name: "win_demo_ip"
          win_nic_name: "win_demo_nic"
          win_admin_user: "azureuser"
          win_admin_password: "RedHatAnsible123!"
        playbook: "project/{{ item.playbook }}"
        credentials:
          - "azure_credential"
        state: "present"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      with_items:
        - { playbook: 'create_windows_vm_demo.yml', name: 'Create Windows Server 2022 VM' }

    - name: Create job template
      awx.awx.job_template:
        name: "{{ item.name }}"
        job_type: "run"
        organization: "Default"
        inventory: "Demo Inventory"
        project: "Azure Demos Project"
        playbook: "project/{{ item.playbook }}"
        credentials:
          - "azure_credential"
        state: "present"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      with_items:
        - { playbook: 'create_rhel_vm_demo.yml', name: 'Create RHEL VM' }

    - name: Create job template
      awx.awx.job_template:
        name: "Cloud Report"
        job_type: "run"
        organization: "Default"
        inventory: "Demo Inventory"
        project: "Cloud Visibility Project"
        playbook: "playbooks/cloud_report_azure.yml"
        credentials:
          - "azure_credential"
        state: "present"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Launch Windows VM into Azure
      awx.awx.job_launch:
        job_template: "Create Windows Server 2022 VM"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      register: job_output

    - name: Wait for job
      awx.awx.job_wait:
        job_id: "{{ job_output.id }}"
        timeout: 3600
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Launch RHEL VM into Azure
      awx.awx.job_launch:
        job_template: "Create RHEL VM"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false
      register: job_output_rhel

    - name: Wait for job
      awx.awx.job_wait:
        job_id: "{{ job_output_rhel.id }}"
        timeout: 3600
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Add an Azure Inventory
      awx.awx.inventory:
        name: "Azure Inventory"
        description: "Our Azure Inventory"
        organization: "Default"
        state: present
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Add an Azure Inventory Source
      awx.awx.inventory_source:
        name: "Azure Source"
        description: "Source for the Azure Inventory"
        inventory: "Azure Inventory"
        credential: "azure_credential"
        source: azure_rm
        overwrite: "True"
        update_on_launch: "True"
        organization: "Default"
        execution_environment: "Microsoft Azure Execution Environment"
        state: present
        source_vars:
          hostnames:
            - computer_name
          compose:
            ansible_host: public_ipv4_address[0]
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

    - name: Update a single inventory source
      awx.awx.inventory_source_update:
        name: "Azure Source"
        inventory: "Azure Inventory"
        organization: "Default"
        controller_username: "{{ username }}"
        controller_password: "{{ admin_password }}"
        controller_host: "https://{{ ansible_host }}"
        validate_certs: false

EOF
export ANSIBLE_LOCALHOST_WARNING=False
export ANSIBLE_INVENTORY_UNPARSED_WARNING=False

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml

# curl -fsSL https://code-server.dev/install.sh | sh
# sudo systemctl enable --now code-server@$USER
