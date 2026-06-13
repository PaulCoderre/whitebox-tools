#!/bin/bash
#SBATCH --job-name=wbt_build
#SBATCH --output=wbt_build_%j.out
#SBATCH --error=wbt_build_%j.err
#SBATCH --account=rrg-alpie
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=01:00:00

module restore scimods

apptainer exec --bind $(pwd):/work --pwd /work ~/containers/geospatial_4.4.0.sif \
  bash -c 'source ~/.cargo/env && cargo build --release --offline -j 8 -p whitebox_tools'