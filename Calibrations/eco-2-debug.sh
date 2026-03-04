#!/bin/bash

#SBATCH --job-name=eco-2-debug
#SBATCH --output=eco-2-debug.txt
#
#SBATCH --ntasks=1
#SBATCH --time=00:30:00
#SBATCH --mem-per-cpu=1G
#SBATCH --partition=debug
#SBATCH --mail-user jamesholehouse1@gmail.com
#SBATCH --mail-type ALL
#SBATCH --cpus-per-task 8

echo Node list: $SLURM_JOB_NODELIST
echo Number of tasks : $SLURM_NTASKS

julia -t 8 ecosystem-calib.jl 2
