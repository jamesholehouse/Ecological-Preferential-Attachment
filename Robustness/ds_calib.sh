#!/bin/bash

#SBATCH --job-name=ds_calib
#SBATCH --output=ds_calib.txt
#
#SBATCH --ntasks=1
#SBATCH --time=1:00:00
#SBATCH --mem-per-cpu=2G
#SBATCH --partition=general
#SBATCH --mail-user jamesholehouse1@gmail.com
#SBATCH --mail-type ALL
#SBATCH --cpus-per-task 20

echo Node list: $SLURM_JOB_NODELIST
echo Number of tasks : $SLURM_NTASKS

julia -t 20 ds_calibration.jl
