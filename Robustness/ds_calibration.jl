# import the relevant packages
using DataFrames, CSV, BlackBoxOptim, Distances, StatsBase, Printf, GLM, DelimitedFiles, LinearAlgebra, Interpolations
include("$(homedir())/GitHub/Ecological-Preferential-Attachment/diversity-simulator.jl")
using .dsim

# import data for the initial condition
read_data = CSV.read("$(homedir())/GitHub/Ecological-Preferential-Attachment/Data_csv/Grilli-crosssecdata__datatax.csv", DataFrame)
read_data = filter(:nreads => !=(0), read_data)
# first split on classification
gd1 = groupby(read_data, :classification);

gd_classes = []
for gd in gd1
    push!(gd_classes, groupby(gd, :sample_id))
end
    
ind_choice = 2;
data = gd_classes[ind_choice];
sizes = sum.([data[x][!,:count] for x in 1:length(data)]);
small_to_large = sortperm(sizes);
ic_sys = sort(data[small_to_large[1]][!,:count],rev=true);

# the vectors that will store the required values of θ, γ
θ_vec_all = Vector{Union{Missing, Float64}}(undef, 20); θ_vec_all .= 0.0;
γ_vec_all = Vector{Union{Missing, Float64}}(undef, 20); γ_vec_all .= 0.0;
fitness_all = Vector{Union{Missing, Float64}}(undef, 20); fitness_all .= 0.0;

# padding function
function pad_rdist(d1, d2)
    min_not_0 = minimum(filter!(x->x!=0,vcat(d1, d2))); # so that the padded values are not exactly zero
    n = max(length(d1), length(d2));
    d1_padded = vcat(d1, ones(n - length(d1))*min_not_0/10); # divide by 10, so as not to punish the distance too badly (could make things too stochastic).
    d2_padded = vcat(d2, ones(n - length(d2))*min_not_0/10);
    return d1_padded, d2_padded, abs(length(d1) - length(d2));
end;

Threads.@threads for j in 1:20
    # relabel the data
    data_rf = CSV.read("./ds_distributions/ds_dist_$(j).csv", DataFrame)[!,:ds_abundance]
    N = sum(data_rf)

    function ibb_fn(S::Array{Float64,1})
        # assign values of model pars
        θ, γ = S[1:2];
        # simulate the organization and collect the norm rf distribution
        osim = dsim.create_cell(θ,γ,1, floor(Int64,N), ic_sys, :pdf)
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
    iSRange = [(-10.0,1.5),(0.2,1.5)];
    iopts = bbsetup(ibb_fn; Method = :adaptive_de_rand_1_bin_radiuslimited, SearchRange = iSRange, 
            NumDimensions = 2, MaxTime = 1.0, PopulationSize = 50, TraceMode=:silent); # 1 day: 86400.0; 1 day and 20 hours: 158400.0
    ires = bboptimize(iopts);
    iopt_par = best_candidate(ires);
    ifitness = best_fitness(ires);

    # store the pars
    θ_vec_all[j] = iopt_par[1]; γ_vec_all[j] = iopt_par[2]; fitness_all[j] = ifitness;
    @printf "Calibration %d out of %d now done, giving parameters θ = %.3f, γ = %.3f with fitness %.3f." j 20 θ_vec_all[j] γ_vec_all[j] ifitness
    println("")
end

df_out = DataFrame(theta=θ_vec_all, gamma=γ_vec_all, fitness = fitness_all);
CSV.write("./inferred_ds_parameters", df_out)