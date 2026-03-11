# import the relevant packages
using DataFrames, CSV, BlackBoxOptim, Distances, StatsBase, Printf, GLM, DelimitedFiles, LinearAlgebra, Interpolations
include("$(homedir())/GitHub/Ecological-Preferential-Attachment/diversity-simulator.jl")
using .dsim

# microbiome number
data_ind = parse(Int64,ARGS[1]);

# import data 
read_data = CSV.read("$(homedir())/GitHub/Ecological-Preferential-Attachment/Data_csv/Grilli-crosssecdata__datatax.csv", DataFrame)

# first split on classification (microbiome type)
gd = groupby(read_data, :classification);
# for the group of interest (given by data_ind) split up the samples
data = groupby(gd[data_ind], :sample_id)

# get the top ten microbiomes by size
sizes = sum.([data[x][!,:count] for x in 1:length(data)]);
top10inds = sortperm(sizes, rev = true)[1:10];

# need to get the initial conditions (smallest ecosystem in the data for that class)
small_to_large = sortperm(sizes)
ic_sys = data[small_to_large[2]]
ic_sys = sort(ic_sys[!,:count], rev=true)

# need to find the bounding value of p0
logxs = log10.(sum.([x[!,:count] for x in data]));
logys = log10.(length.([x[!,:count] for x in data]));
df = DataFrame(y = logys, x = logxs);
glm = lm(@formula(y ~ x), df);
a,b = coef(glm);
θ = 2+1/(b-1);
α = sum([k^θ for k in ic_sys])/(sum(ic_sys)^(1/(2-θ)));
p0_guess = α*b*10^a; # based on the analytics from [Yang, V. C., Holehouse, J., Youn, H., Arroyo, J. I., Redner, S., West, G. B., & Kempes, C. P. (2026). Scaling laws for function diversity and specialization across socioeconomic and biological complex systems. Proceedings of the National Academy of Sciences, 123(7), e2509729123.]

println("Data imported.")

"""
Set up parallel prog
"""
# take the number of threads
nth = Threads.nthreads()
# find the number of sims to run on each thread, try and equate
runs_per_th = [floor(Int,10/nth) for i in 1:nth]
if sum(runs_per_th) != 10+1
    remn = 10 % sum(runs_per_th)
    for i in 1:remn
        ind = i%length(runs_per_th)
        runs_per_th[ind] += 1
    end
end
            
println("Parallel prog set-up.")

"""
The actual calibration: set up BBO and run.
"""

# the vectors that will store the required values of θ, γ
θ_vec_all = Vector{Union{Missing, Float64}}(undef, 10); θ_vec_all .= 0.0;
γ_vec_all = Vector{Union{Missing, Float64}}(undef, 10); γ_vec_all .= 0.0;
fitness_all = Vector{Union{Missing, Float64}}(undef, 10); fitness_all .= 0.0;

# padding function
function pad_rdist(d1, d2)
    min_not_0 = minimum(filter!(x->x!=0,vcat(d1, d2))); # so that the padded values are not exactly zero
    n = max(length(d1), length(d2));
    d1_padded = vcat(d1, ones(n - length(d1))*min_not_0/10); # divide by 10, so as not to punish the distance too badly (could make things too stochastic).
    d2_padded = vcat(d2, ones(n - length(d2))*min_not_0/10);
    return d1_padded, d2_padded, abs(length(d1) - length(d2));
end;

println("Storage vectors initialized.")

# Loop over each ecosystem in the selected part of the data, and store the parameters found via the optimisation into the vectors.
# Each thread runs a set number of calibrations specified in runs_per_th
Threads.@threads for iter in 1:nth
    println("Running thread $iter.")
    for j in 1:runs_per_th[iter]
        # find the index of the initial rf data array
        if iter == 1
            i = j
        else
            i = sum(runs_per_th[1:iter-1])+j
        end

        # relabel the data
        data_rf = sort(vcat(data[top10inds[i]][!,:count]), rev=true)
        N = sum(data_rf)

        function ibb_fn(S::Array{Float64,1})
            # assign values of model pars
            θ, γ = S[1:2];
            # simulate the organization and collect the norm rf distribution
            osim = dsim.create_cell(θ,γ,p0_guess, floor(Int64,N), ic_sys, :pdf)
            df_norm = data_rf/sum(data_rf)
            osim_norm = osim/sum(osim)

            # need to pad the distributions 
            df_norm_pad, osim_norm_pad = pad_rdist(df_norm, osim_norm)
            # find the logarithm of elements for the distance calculation
            df_norm_pad_log, osim_norm_pad_log = log.(df_norm_pad), log.(osim_norm_pad)
            euc_log = euclidean(df_norm_pad_log, osim_norm_pad_log)
            return euc_log
        end

        println("Starting optimizations.")

        # run the opt
        iSRange = [(-10.0,1.0),(0.2,1.5)];
        iopts = bbsetup(ibb_fn; Method = :adaptive_de_rand_1_bin_radiuslimited, SearchRange = iSRange, 
                NumDimensions = 2, MaxTime = 86400.0, PopulationSize = 50, TraceMode=:silent); # 1 day: 86400.0
        ires = bboptimize(iopts);
        iopt_par = best_candidate(ires);
        ifitness = best_fitness(ires);

        # store the pars
        θ_vec_all[i] = iopt_par[1]; γ_vec_all[i] = iopt_par[2]; fitness_all[i] = ifitness;
        @printf "Calibration %d out of %d now done, giving parameters θ = %.3f, γ = %.3f with fitness %.3f." i 10 θ_vec_all[i] γ_vec_all[i] ifitness
        println("")
    end
end

df_out = DataFrame(theta=θ_vec_all, gamma=γ_vec_all, fitness = fitness_all);
CSV.write("$(homedir())/GitHub/Ecological-Preferential-Attachment/Calibrations/calibration_results_p0_fixed2/eco-calib-$(data_ind).csv", df_out)
pwd()





































