
#!/bin/bash

set -e

echo "Creating .gitkeep files..."

# Ensure all directories exist
mkdir -p application/frontend
mkdir -p application/backend
mkdir -p application/database

mkdir -p terraform/modules
mkdir -p terraform/environments/dev

mkdir -p ansible
mkdir -p jenkins
mkdir -p kubernetes

mkdir -p helm/shopsphere

mkdir -p monitoring/prometheus
mkdir -p monitoring/grafana

mkdir -p docs

# Create .gitkeep files
touch application/frontend/.gitkeep
touch application/backend/.gitkeep
touch application/database/.gitkeep

touch terraform/modules/.gitkeep
touch terraform/environments/dev/.gitkeep

touch ansible/.gitkeep
touch jenkins/.gitkeep
touch kubernetes/.gitkeep

touch helm/shopsphere/.gitkeep

touch monitoring/prometheus/.gitkeep
touch monitoring/grafana/.gitkeep

touch docs/.gitkeep

echo "=================================="
echo "All .gitkeep files created!"
echo "=================================="

find . -name ".gitkeep"

