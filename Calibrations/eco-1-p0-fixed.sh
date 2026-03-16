#!/bin/bash

#SBATCH --job-name=eco-1
#SBATCH --output=eco-1.txt
#
#SBATCH --ntasks=1
#SBATCH --time=47:00:00
#SBATCH --mem-per-cpu=5G
#SBATCH --partition=general
#SBATCH --mail-user jamesholehouse1@gmail.com
#SBATCH --mail-type ALL
#SBATCH --cpus-per-task 10

echo Node list: $SLURM_JOB_NODELIST
echo Number of tasks : $SLURM_NTASKS

julia -t 10 ecosystem-calib-p0-fixed.jl 1
