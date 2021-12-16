### A Pluto.jl notebook ###
# v0.17.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 0782768c-951f-4189-954d-cba8b401314d
begin

	# load some external packages 
	using PlutoUI
	using DataFrames
	using BSON
	using GLPK
	using PrettyTables
	using Plots
	using CSV
	using Optim 
	using Statistics 
	using LinearAlgebra
	using Plots
	using TypedTables
	
	# setup my paths (where are my files?)
	_PATH_TO_ROOT = pwd() 
	_PATH_TO_SRC = joinpath(_PATH_TO_ROOT,"src")
	_PATH_TO_MODEL = joinpath(_PATH_TO_ROOT,"model")
	_PATH_TO_FIGS = joinpath(_PATH_TO_ROOT,"figs")
	
	# load the ENGRI 1120 project code library -
	include(joinpath(_PATH_TO_SRC,"Include.jl"))

	# load the model -
	MODEL = BSON.load(joinpath(_PATH_TO_MODEL,"model_v2.bson"), @__MODULE__)

	# show -
	nothing
end

# ╔═╡ 4855467c-3670-4e0b-a64e-0e09effa6e0d
md"""
## ENGRI 1120: Design and Analysis of a Sustainable Cell-Free Production Process for Industrially Important Small Molecules
"""

# ╔═╡ 8ca99e1f-afd6-4c1c-8918-db6d9747099c
html"""
<p style="font-size:20px;">
Team name: Super Swag Super Heated Steam Engines </br>
Team Members: Lauren de Silva, Dennis Wu, Henry Lin </br>
Smith School of Chemical and Biomolecular Engineering, Cornell University, Ithaca NY 14850</p>
"""

# ╔═╡ a0ad3474-1844-41bc-bd95-242aa94a5ff1
md"""
### Introduction
"""

# ╔═╡ 27d0013a-3c23-4f92-a334-5e4b55e2447e
md"""PDGN (1,2-propanediol dinitrate or propane glycol dinitrate) is a compound commonly found in propellants and explosives. It is an nitrate ester high explosive that is found both in the liquid propellant and the liquid explosive form [5]. The US navy is a main consumer of Otto Fuel II, a torpedo fuel that comprises approximately 76% PGDN[2] . In this work, we analyze how to manufacture PDGN at 95% purity and stream rate of at least 1.0g/hour in an E. Coli cell-free bioreactor from alpha-d-glucose, a renewable sugar feedstock, in addition to oxygen and potassium nitrate. 

Through this glucose based method, which is accessible all around the world,  we aim to propose a more economically feasible method of producing PDGN. Using oxygen from the air and potassium nitrate, we can develop a relatively cost efficient process that is inexpensive in comparison to current production methods.

Although there is no direct route from sucrose to PGDN, the bioreactor allows us to take advantage of the glycolysis of sucrose in the bioreactor. This reaction mechanism follows the follow chemical equations: 

* (1) ATP + alpha-D-Glucose ⇌ ADP + alpha-D-Glucose 6-phosphate-

* (2)Alpha-D-Glucose 6-phosphate ⇌ beta-D-Fructose 6-phosphate

* (3)beta-D-Fructose 1,6-bisphosphate ⇌ Glycerone phosphate + D-Glyceraldehyde 3-phosphate

* (4)D-Glyceraldehyde 3-phosphate ⇌ Glycerone phosphate

* (5)Glycerone phosphate ⇌ Methylglyoxal + Orthophosphate

* (6)Methylglyoxal + NADPH + H+ ⇌ (S)-Lactaldehyde + NADP+

* (7)(S)-Lactaldehyde + NADH + H+ ⇌ Propane-1,2-diol + NAD+

* (8)Propane-1,2-diol + 2KNO3 ⇌ PDGN + 2KOH

The only addition to this biological reaction is potassium nitrate in order to produce the PDGN. The overall reaction follows the equation:

$$glucose + 2KNO_3 ⇌ PDGN + 2KOH + CO_2 + excess-materials$$

Our goal is to determine the most economically efficient pathway to synthesize the PGDN specifically looking at the sucrose reaction mechanism above. 
"""

# ╔═╡ 40da982c-1cc4-4881-a2ea-fbeef5c46d2d
md"""
### Materials and Methods
"""

# ╔═╡ 446bd227-6579-4c87-8588-0de111c5a529
md""" ##### Flux Balance Analysis Assumptions and Methods
The primary method used to compute the optimal open extent of reaction was a flux balance analysis. The flux balance is a practice of optimizing the genetic processes within the cell to increase the production of what we need. This form of metabolic engineering is modeled in the flux balance code used below. The program uses a linear equation as follows: 
max vi=sum c1v1
The equation seeks to take the metabolic flux of the objective coefficient and subject it to two constraints of the metabolic flux to find the optimal flux. To use the flux balance analysis we make the simplifying assumptions that the microfluidic chip used is well-mixed and operates at steady-state. Also that the chip is being run at a constant temperature and pressure and that the liquid phase is ideal. 

The program reads that the optimal reaction extent is 2.466 mmol/hr. This is our maximum flow of PGDN we can create from just one chip. After this is established we move onto setting up a series of these reactors to maximize the flow of our stream. 
"""



# ╔═╡ 4867b51c-fb6c-42a9-b87d-4131e014b402
md"""
##### Setting up the Flux Balance Analysis (FBA) calculation to estimate of optimal reaction rates
"""

# ╔═╡ 059e3b4e-4e84-4934-b787-32d0f42a0247
begin

	# setup the FBA calculation for the project -

	# === SELECT YOUR PRODUCT HERE ==================================================== #
	# What rate are trying to maximize? (select your product)
	# rn:R08199 = isoprene
	# rn:28235c0c-ec00-4a11-8acb-510b0f2e2687 = PGDN
	# rn:rn:R09799 = Hydrazine
	# rn:R03119 = 3G
	idx_target_rate = find_reaction_index(MODEL,:reaction_number=>"rn:28235c0c-ec00-4a11-8acb-510b0f2e2687")
	# ================================================================================= #

	# First, let's build the stoichiometric matrix from the model object -
	(cia,ria,S) = build_stoichiometric_matrix(MODEL);

	# Next, what is the size of the system? (ℳ = number of metabolites, ℛ = number of reactions)
	(ℳ,ℛ) = size(S)

	# Next, setup a default bounds array => update specific elements
	# We'll correct the directionality below -
	Vₘ = (13.7)*(3600)*(50e-9)*(1000) # units: mmol/hr
	flux_bounds = [-Vₘ*ones(ℛ,1) Vₘ*ones(ℛ,1)]

	# update the flux bounds -> which fluxes can can backwards? 
	# do determine this: sgn(v) = -1*sgn(ΔG)
	updated_flux_bounds = update_flux_bounds_directionality(MODEL,flux_bounds)

	# hard code some bounds that we know -
	updated_flux_bounds[44,1] = 0.0  # ATP synthesis can't run backwards 

	# What is the default mol flow input array => update specific elements
	# strategy: start with nothing in both streams, add material(s) back
	n_dot_input_stream_1 = zeros(ℳ,1)	# stream 1
	n_dot_input_stream_2 = zeros(ℳ,1)	# stream 2

	# === YOU NEED TO CHANGE BELOW HERE ====================================================== #
	# Let's lookup stuff that we want/need to supply to the chip to get the reactiont to go -
	# what you feed *depends upon your product*
	compounds_that_we_need_to_supply_feed_1 = [
		"alpha-d-glucose", "potassium nitrate"
	]

	# what are the amounts that we need to supply to chip in feed stream 1 (units: mmol/hr)?
	mol_flow_values_feed_1 = [
		13 ; # alpha-d-glucose mmol/hr
		30 ; #potassium nitrate mmol/hr
	]

	# what is coming into feed stream 2?
	compounds_that_we_need_to_supply_feed_2 = [
		"oxygen"
	]

	# let's always add Vₘ into feed stream 2
	mol_flow_values_feed_2 = [
		0.615; # oxygen mmol/hr
	]
	
	
	# === YOU NEED TO CHANGE ABOVE HERE ====================================================== #

	# stream 1:
	idx_supply_stream_1 = Array{Int64,1}()
	for compound in compounds_that_we_need_to_supply_feed_1
		idx = find_compound_index(MODEL,:compound_name=>compound)
		push!(idx_supply_stream_1,idx)
	end

	# stream 2:
	idx_supply_stream_2 = Array{Int64,1}()
	for compound in compounds_that_we_need_to_supply_feed_2
		idx = find_compound_index(MODEL,:compound_name=>compound)
		push!(idx_supply_stream_2,idx)
	end
	
	# supply for stream 1 and stream 2
	n_dot_input_stream_1[idx_supply_stream_1] .= mol_flow_values_feed_1
	n_dot_input_stream_2[idx_supply_stream_2] .= mol_flow_values_feed_2
	
	# setup the species bounds array -
	species_bounds = [-1.0*(n_dot_input_stream_1.+n_dot_input_stream_2) 1000.0*ones(ℳ,1)]

	# Lastly, let's setup the objective function -
	c = zeros(ℛ)
	c[idx_target_rate] = -1.0

	# show -
	nothing
end

# ╔═╡ 7410ecfc-0280-4ff2-8932-cfb2022e47c4
begin

	# compute the optimal flux -
	result = calculate_optimal_flux_distribution(S, updated_flux_bounds, species_bounds, c);

	# get the open extent vector -
	ϵ_dot = result.calculated_flux_array

	# what is the composition coming out of the first chip?
	n_dot_out_chip_1 = (n_dot_input_stream_1 + n_dot_input_stream_2 + S*ϵ_dot);

	# did this converge?
	with_terminal() do

		# get exit/status information from the solver -
		exit_flag = result.exit_flag
		status_flag = result.status_flag

		# display -
		println("Computed optimal flux distribution w/exit_flag = 0: $(exit_flag==0) and status_flag = 5: $(status_flag == 5)")
	end
end

# ╔═╡ 64daa21a-ac42-4b20-9e6b-ec2d19cd50fc
md"""
###### Table 1: Optimal reaction extent table computed by flux balance analysis. 

Each row corresponds to a reaction in the model where $\dot{\epsilon}_{i}$ denotes the optimal open reaction extent computed by flux balance analysis. 
"""

# ╔═╡ 637c5a39-63db-4d76-bb4c-ecc819482036
md""" ##### Connecting the Chip Reactions in Series"""

# ╔═╡ ae718670-bd74-48f5-96ed-d45a8d3bccb9
md"""Though one chip produces 2.466 mmol/hr, the output stream is  not solely composed of PGDN. We must arrange the chips in a series to achieve our goal of having a pure output of 1g/hr. From the program outlined below, a output of 14.796mmol/hr is found to produce enough PGDN in the stream to achieve our goal. We need approximately 6 chips to have enough PGDN after purification. Placing the chips in series is overall more economically efficient as it yields a higher output with fewer chips. The assumptions we make are that the microfluidic chip is well-mixed and operates at steady-state, the chip remains at constant temperature, pressure and the liquid phase is ideal.
"""

# ╔═╡ 3d84169a-3a85-4d9f-b7bb-b7264017fbb8
begin

	# setup calculation for chips i = 2,....,N
	N = 6 # number of chips

	# initialize some space to store the mol flow rates -
	series_mol_state_array = zeros(ℳ,N)
	exit_flag_array = Array{Int64,1}()
	status_flag_array = Array{Int64,1}()

	# the initial col of this array is the output of from chip 1
	for species_index = 1:ℳ
		series_mol_state_array[species_index,1] = n_dot_out_chip_1[species_index]
	end
	
	# assumption: we *always* feed glycerol into port 2 - so we only need to update the input flow into port 1
	for chip_index = 2:N

		# update the input into the chip -
		n_dot_input_port_1 = series_mol_state_array[:,chip_index - 1] 		# the input to chip j comes from j - 1
	
		# setup the species bounds array -
		species_bounds_next_chip = [-1.0*(n_dot_input_port_1.+n_dot_input_stream_2) 1000.0*ones(ℳ,1)]

		# run the optimal calculation -
		result_next_chip = calculate_optimal_flux_distribution(S, updated_flux_bounds, species_bounds_next_chip, c);

		# grab the status and exit flags ... so we can check all is right with the world ...
		push!(exit_flag_array, result_next_chip.exit_flag)
		push!(status_flag_array, result_next_chip.status_flag)

		# Get the flux from the result object -
		ϵ_dot_next_chip = result_next_chip.calculated_flux_array

		# compute the output from chip j = chip_index 
		n_dot_out_next_chip = (n_dot_input_port_1 + n_dot_input_stream_2 + S*ϵ_dot_next_chip);

		# copy this state vector into the state array 
		for species_index = 1:ℳ
			series_mol_state_array[species_index,chip_index] = n_dot_out_next_chip[species_index]
		end

		# go around again ...
	end
end

# ╔═╡ d541352c-4956-4bbe-a11a-27f78f3b8afe
exit_flag_array

# ╔═╡ 538f7122-e6ae-4256-8756-cd41d27ca085
status_flag_array

# ╔═╡ e933ddd9-8fd8-416a-8710-a64d3eb36f79
md"""
###### Table 2: State table from a single chip (species mol flow rate mmol/hr at exit). 

The mass flow for all species at the exit of the chip is encoded in the `mass_dot_output_array` array.
"""

# ╔═╡ 7d35f315-927c-44b2-948a-c4e3d273a5e1
begin

	# what chip r we looking at?
	n_dot_output_chip = series_mol_state_array[:,end]

	# get the array of MW -
	MW_array = MODEL[:compounds][!,:compound_mw]

	# convert the output mol stream to a mass stream -
	mass_dot_output = (n_dot_output_chip.*MW_array)*(1/1000)

	# what is the total coming out?
	total_mass_out = sum(mass_dot_output)
	
	# display code makes the table -
	with_terminal() do

		# what are the compound names and code strings? -> we can get these from the MODEL object 
		compound_name_strings = MODEL[:compounds][!,:compound_name]
		compound_id_strings = MODEL[:compounds][!,:compound_id]
		
		# how many molecules are in the state array?
		ℳ_local = length(compound_id_strings)
	
		# initialize some storage -
		number_of_cols = 3 + N + 2
		state_table = Array{Any,2}(undef,ℳ_local,number_of_cols)

		# get the uptake array from the result -
		uptake_array = result.uptake_array

		# populate the state table -
		for compound_index = 1:ℳ_local
			state_table[compound_index,1] = compound_index
			state_table[compound_index,2] = compound_name_strings[compound_index]
			state_table[compound_index,3] = compound_id_strings[compound_index]

			for chip_index = 1:N
				tmp_value = abs(series_mol_state_array[compound_index, chip_index])
				state_table[compound_index,chip_index + 3] = (tmp_value) <= 1e-6 ? 0.0 : 
					series_mol_state_array[compound_index, chip_index]
			end

			# show the mass -
			tmp_value = abs(mass_dot_output[compound_index])
			state_table[compound_index,(N + 3 + 1)] = (tmp_value) <= 1e-6 ? 0.0 : mass_dot_output[compound_index]

			# show the mass fraction -
			# show the mass -
			tmp_value = abs(mass_dot_output[compound_index])
			state_table[compound_index, (N + 3 + 2)] = (tmp_value) <= 1e-6 ? 0.0 : 	
				(1/total_mass_out)*mass_dot_output[compound_index]
		end

		# build the table header -
		id_header_row = Array{String,1}()
		units_header_row = Array{String,1}()

		# setup id row -
		push!(id_header_row, "i")
		push!(id_header_row, "name")
		push!(id_header_row, "id")
		for chip = 1:N
			push!(id_header_row, "Chip $(chip)")
		end
		push!(id_header_row, "m_dot")
		push!(id_header_row, "ωᵢ_output")

		# setup units header row -
		push!(units_header_row, "")
		push!(units_header_row, "")
		push!(units_header_row, "")
		for chip = 1:N
			push!(units_header_row, "mmol/hr")
		end
		push!(units_header_row, "g/hr")
		push!(units_header_row, "")
		
		# header row -
		state_table_header_row = (id_header_row, units_header_row)
		
		# write the table -
		pretty_table(state_table; header=state_table_header_row)
	end
end

# ╔═╡ 7720a5a6-5d7e-4c79-8aba-0a4bb04973af
md"""
##### Compute the downstream separation using Magical Separation Units (MSUs)
"""

# ╔═╡ 8530bb61-ab28-4747-8037-0b9d481685a7
md"""After we obtained the 14.796mmol/hr stream, we then set up magical separator units that are 75% efficient in purifying our stream. The magical separator unit program works by establishing a theta value to which we assign the goal purity of our stream. In this scieneitro it is 0.75.  Then the program computes the composition of the upstream. Each level of separation added, we achieve a high purity. A minimum of 4 levels are needed to achieve  95.6 % purity at 1.08g/hr. To reduce cost, we decided to not filter out the waste stream for the main byproducts, potassium hydroxide and acetate, do not provide a significant return on value. Note: The MSU's are purely hypotheical and make the assumptions that the seperation of each stream occurs at exaclty 75% efficency and that the each of the streams are ideal  
"""


# ╔═╡ 87e21b0b-5f6b-4402-baf3-68a150ef0fc2
md"""
Reaction string format: $(@bind rxn_string_ver Select(["first"=>"KEGG", "second"=>"HUMAN"]))
"""


# ╔═╡ 77df0589-a5a0-45cf-a0db-156621634262
with_terminal() do

	# initialize some storage -
	flux_table = Array{Any,2}(undef,ℛ,6)

	# what are the reaction strings? -> we can get these from the MODEL object 
	reaction_strings = MODEL[:reactions][!,:reaction_markup]
	reaction_id = MODEL[:reactions][!,:reaction_number]

	# translate the reaction string to HUMAN -
	human_rxn_string_array = translation_reaction_string_to_human(MODEL)

	# populate the state table -
	for reaction_index = 1:ℛ
		flux_table[reaction_index,1] = reaction_index
		flux_table[reaction_index,2] = reaction_id[reaction_index]
		
			if (rxn_string_ver == "first")
				flux_table[reaction_index,3] = reaction_strings[reaction_index]
			else
				flux_table[reaction_index,3] = human_rxn_string_array[reaction_index]
		end
		flux_table[reaction_index,4] = flux_bounds[reaction_index,1]
		flux_table[reaction_index,5] = flux_bounds[reaction_index,2]

		# clean up the display -
		tmp_value = abs(ϵ_dot[reaction_index])
		flux_table[reaction_index,6] = tmp_value < 1e-6 ? 0.0 : ϵ_dot[reaction_index]
	end
		# header row -
	flux_table_header_row = (["i","RID","R","ϵ₁_dot LB", "ϵ₁_dot UB", "ϵᵢ_dot"],
		["","","", "mmol/hr", "mmol/hr", "mmol/hr"]);
		
	# write the table -
	pretty_table(flux_table; header=flux_table_header_row)
end


# ╔═╡ e1da943a-0d11-4776-bb67-2d8caad4cb18
# how many levels are we going to have in the separation tree?
number_of_levels = 4

# ╔═╡ 28a9763c-c5e1-41ae-b52c-445bcb839755
begin

	# define the split -
	θ = 0.75

	# most of the "stuff" has a 1 - θ in the up, and a θ in the down
	u = (1-θ)*ones(ℳ,1)
	d = θ*ones(ℳ,1)

	# However: the desired product has the opposite => correct for my compound of interest -> this is compound i = ⋆
	idx_target_compound = find_compound_index(MODEL,:compound_name=>"PGDN")

	# correct defaults -
	u[idx_target_compound] = θ
	d[idx_target_compound] = 1 - θ

	# let's compute the composition of the *always up* stream -
	
	# initialize some storage -
	species_mass_flow_array_top = zeros(ℳ,number_of_levels)
	species_mass_flow_array_bottom = zeros(ℳ,number_of_levels)

	for species_index = 1:ℳ
		value = mass_dot_output[species_index]
		species_mass_flow_array_top[species_index,1] = value
		species_mass_flow_array_bottom[species_index,1] = value
	end
	
	for level = 2:number_of_levels

		# compute the mass flows coming out of the top -
		m_dot_top = mass_dot_output.*(u.^(level-1))
		m_dot_bottom = mass_dot_output.*(d.^(level-1))

		# update my storage array -
		for species_index = 1:ℳ
			species_mass_flow_array_top[species_index,level] = m_dot_top[species_index]
			species_mass_flow_array_bottom[species_index,level] = m_dot_bottom[species_index]
		end
	end
	
	# what is the mass fraction in the top stream -
	species_mass_fraction_array_top = zeros(ℳ,number_of_levels)
	species_mass_fraction_array_bottom = zeros(ℳ,number_of_levels)

	# array to hold the *total* mass flow rate -
	total_mdot_top_array = zeros(number_of_levels)
	total_mdot_bottom_array = zeros(number_of_levels)
	
	# this is a dumb way to do this ... you're better than that JV come on ...
	T_top = sum(species_mass_flow_array_top,dims=1)
	T_bottom = sum(species_mass_flow_array_bottom,dims=1)
	for level = 1:number_of_levels

		# get the total for this level -
		T_level_top = T_top[level]
		T_level_bottom = T_bottom[level]

		# grab -
		total_mdot_top_array[level] = T_level_top
		total_mdot_bottom_array[level] = T_level_bottom

		for species_index = 1:ℳ
			species_mass_fraction_array_top[species_index,level] = (1/T_level_top)*
				(species_mass_flow_array_top[species_index,level])
			species_mass_fraction_array_bottom[species_index,level] = (1/T_level_bottom)*
				(species_mass_flow_array_bottom[species_index,level])
		end
	end
end

# ╔═╡ 24d220cd-0ead-44f1-9327-9db647b8108b
begin

	stages = (1:number_of_levels) |> collect
	plot(stages,species_mass_fraction_array_top[idx_target_compound,:], linetype=:steppre,lw=2,legend=:bottomright, 
		label="Mass fraction i = PDO Tops")
	xlabel!("Stage index l",fontsize=18)
	ylabel!("Tops mass fraction ωᵢ (dimensionless)",fontsize=18)

	# make a 0.95 line target line -
	target_line = 0.95*ones(number_of_levels)
	plot!(stages, target_line, color="red", lw=2,linestyle=:dash, label="Target 95% purity")
end

# ╔═╡ cf367be1-ebde-4f46-974c-e2fdd1fdd903
with_terminal() do

	# initialize some space -
	state_table = Array{Any,2}(undef, number_of_levels, 3)
	for level_index = 1:number_of_levels
		state_table[level_index,1] = level_index
		state_table[level_index,2] = species_mass_fraction_array_top[idx_target_compound, level_index]
		state_table[level_index,3] = total_mdot_top_array[level_index]
	end
	
	# header -
	state_table_header_row = (["stage","ωᵢ i=⋆ top","mdot"],
			["","","g/hr"]);

	# write the table -
	pretty_table(state_table; header=state_table_header_row)
end

# ╔═╡ ea3305ae-cb8e-4a2b-83e2-ef882223e961
html"""
<style>
main {
    max-width: 1200px;
    width: 85%;
    margin: auto;
    font-family: "Roboto, monospace";
}

a {
    color: blue;
    text-decoration: none;
}

.H1 {
    padding: 0px 30px;
}
</style>"""

# ╔═╡ 77107b01-dae9-4900-b9f7-f0c0224a492b
md"""
### Results and Discussion
"""

# ╔═╡ dcb915aa-e721-4080-a3fb-71b15d0b866d
md"""Although originally it was suggested that the sugar feedstocks be sucrose, we would advise the use of alpha-d-glucose instead. This sugar not only leads to a lower materials cost, but also produces a lower concentration of CO2 gas. Through a flux balance analysis, it was found that 1.08429g/hr of PDGN of 95.6% purity could be produced using 30mmol/hr of KNO3 and 13mmol/hr alpha glucose in stream 1, and .615mmol/hr in stream 2. With the reactor running for 24 hours a day, and the PDGN being sold for $1.20/gram, this process provides a $31.23 return each day. 
The complete process requires 6 reactor chips, 4 separators, and 1 pump, with total equipment cost of $1680.00. The total cost of materials per day was calculated to be $0.72. Using this information, it was found that the entire process would take approximately 55 days to break even on this investment, and the total profit after the first year (based off of 252 trading days) is $6009.32. After this first year, the total profit per year is $7689.63.

The net present value of these final results and this reaction mechanism set at a 10% discount rate was then compared to an alternative investment with a 10% risk free interest rate that is constant over the payback lifetime, 5 years. The net present value of this process was calculated to be $25,932, a more favorable performance in comparison to investing the original $1,680 equipment cost in the alternative.
"""

# ╔═╡ 218fa01e-5230-49bb-a48a-ebafe81dac4a
md"""
##### *Financial Anylsis Using Net Present Value (NPV) Reuslts* 
"""


# ╔═╡ 4030c9b7-b30d-462d-9d28-b8c2ba11a5e9
md"""
 ###### **Table 1** summarizes the cost and inventory needed for the process on Day 1.
"""



# ╔═╡ cf16db05-b530-4693-8607-f1f45aa702cc
with_terminal() do
data = ["Reactors" "100.00" "100.00" "6" "N/A" "N/A" "600.00"
		"Separators" "20.00" "20.00" "4" "N/A" "N/A" "80.00"
		"Pump" "1,000.00" "1,000.00" "1" "N/A" "N/A" "1,000.00"
		"Alpha D-Glucose" "17.90 per 25 grams" "0.72 per gram" "N/A" "0.00882764" "0.21186336" "0.15"
		"Oxygen" "Free" "Free" "N/A" "Free" "Free" "Free"
		"Potassium Nitrate" "57 per 100 grams" "0.57 per gram" "N/A" "0.0412501" "0.9900024" "0.56" 
		"PGDN" "1196.5 per 1 kg" "1.20 per gram" "N/A" "1.08429" 		"26.02296" "31.23"];

header=(["Items", "Purchase Cost", "Calculation Cost", "Number of Equipment Purchased", "Mass Flow Rates", "Cost to run for 24 hours ", "Total Costs after 1 day"],["dollars","dollars","dollars","","g/hr","dollars","dollars"])

hl_lastRow = Highlighter(f      = (data, i, j) -> i %7 == 0,
                            crayon = Crayon(background = :light_blue))
hl_lastColumn = Highlighter(f      = (data, i, j) -> j %7 == 0,
                            crayon = Crayon(background = :light_blue))
pretty_table(data; header,highlighters =(hl_lastColumn, hl_lastRow))
end




# ╔═╡ 22178cca-c670-4d4f-9021-22328447f9d3
md"""
###### *Note: The last highlighted row represents the revenue made on a day-to-day basis from selling the final product (1,2-propanediol dinitrate).* 


From Table 1 above, the total initial (capital) cost for equipment and to run the process on Day 1 accumulates to a total of $1680.72. Then, the cost to run the process will be an additional cost of $0.72 each day. This simple relationship is summarized in the linear equation below. 



$$TotalSpendingOnDayX = 0.76x+1680.72$$

On the revenue side, the product that is sold each day provides a return of $31.23. 

Total Revenue on Day

$$TotalSpendingOnDayX= 31.23x$$

As a result, it would take roughly 55 days of running the entire process to break even on the investment (by calculating for x). Additionally, at the end of the first year (following the typical 252 trading days rule), the total profit will sit at $6009.32. The results are summarized in Table 2. 


"""

# ╔═╡ d6e3755f-8c25-4627-90a8-e056fc2b640b
md"""
 ###### **Table 2**
"""

# ╔═╡ cbe36492-a695-4514-bbd8-c2df553a120d
with_terminal() do
data = ["Total Spending" "1,680.72" "1681.44" "1682.16" "1,719.43" "1,720.14" "1,860.64"
"Total Revenue" "1.23" "31.23" "31.23" "1,717.65" "1,748.88" "7,869.96"
"Profit" "-1649.49" "-1650.21" "-1650.93" "-1.78" "28.74" "6,009.32"
];

header=(["" ,"Inital Cost", "Cost on Day 1", "Cost on Day 2", "After 55 days", "After 56 Days", "After 1 year(252 days)"], ["","dollars", "dollars", "dollars", "dollars", "dollars", "dollars"])

pretty_table(data; header)
end

# ╔═╡ af08e78f-2910-47d6-a4c9-0e01ec0a7697
md"""  **Table 3**: Total Profit Process Generates Over the Course of 5 years. 
"""

# ╔═╡ eef3b8c8-410e-4880-a55e-2a09c065bef2
with_terminal() do
data = [
"Total Spending" "1,860.64" "2,041.29" "2,221.93" "2,403.29" "2,583.94" 
"Total Revenues" "7,869.96" "15,739.92" "23,609.88" "31,479.84" "39,349.80" 
"Total Profit" "6,009.32" "13,698.63" "21,387.95" "29,076.55" "36,765.86" 
"Difference from prior year" "6,009.32" "7689.63" "7689.63" "7689.63" "7689.63" 
];

header=(["","After 1 Year","After 2 Years","After 3 Years", "After 4 Years","After 5 Years"],["","(252 days)","(504 days)","(756 days)", "(1008 days)","(1260 days)"],["", "dollars", "dollars", "dollars", "dollars", "dollars"])

hl_lastRow = Highlighter(f = (data, i, j) -> i %3 == 0,
                            crayon = Crayon(background = :light_blue))

pretty_table(data; header,highlighters =hl_lastRow)
end

# ╔═╡ 7850b71d-d834-43ce-9775-77e8c6e7513b
md"""

As noted after the first year profit of $6,009.32, the process produces a constant profit of $7689.63 each year. 

These final results were compared to an alternative investment at both a constant 10% discount rate and at a constant 1% discount rate via the Net Present Value method. 
* The lifetime of the comparison was set to 5 years. 
* The constant discount rate was set to 10% or 0.1 in the parameters, indicating a comparison to a 10% risk-free interest rate that is constant over the payback lifetime.
* Since the cash flow array was in the thousands, the values were imputed as listed: [-1.68, 6.0, 7.689, 7.689, 7.689, 7.689]. The initial -1.68 represents the initial (capital) investment that was made, and each of the following terms represents the total profit made each year following this investment. 
* The Present Value of the cash values are as listed: [-1.68, 5.45455, 6.35455, 5.77686, 5.25169, 4.774326]. And then by summing up these values, the Net Present Value is calculated to be 25.9319. 
* Since the Net Present Value is positive, the project would be a better investment of the initial amount of $1,680 than an alternative investment at a 10% interest rate. 
* The same logic can be applied to an alternative investment at a 1% interest rate. 

Using the Net Present Value approach, the process performance is indeed more economically feasible than both the alternative investments at a constant yield of 1 % per year or at a constant yield of 10% per year. 

"""

# ╔═╡ ab9084e1-57a2-4c6b-ad32-8fee8c142c43
md"""
### Conclusions
"""

# ╔═╡ 3bea3df5-a395-4831-ab43-1c713deb69f2
md"""
While the sucrose to PGDN pathway is a feasible option, it is more economically efficient to use alpha-d-glucose as the starting material. When transferring from sucrose to alpha-d-glucose there was a reduction in co2 production resulting making this pathway a slightly more environmentally favorable option. The pathway analyzed in this reaction is advisable as an alternative to the direct production feeding in 1-2propaindiol and KNO3. The downsides of this reaction is that in creating the PGDN, the Co2 byproduct is approximately 1.25x the amount of PGDN synthesized. [4]Methods such as absorption, adsorption, chemical looping, membrane gas separation or gas hydration have been seen to be useful in capturing Co2. The Co2 emissions should be readily monitored and to ensure it does not exceed a certain threshold. These measures must be taken into account, and thus are one downside to the process. [1] Co2, if captured, however, can be sold back to the food production industry for beverages and other sources. The scale of production of the PGDN would have to be significantly greater for this to be an economically viable option. In addition to the Co2 byproduct, the reaction also produces significant amounts of potassium hydroxide and acetate. [7] Potassium Hydroxide is relatively cheap thus is not worth filtering and selling. This chemical however must be carefully disposed of by diluting and neutralizing. Potassium hydroxide is potentially detrimental to air, soil, and water quality and regulations must be carefully abided by during the production process. [6] The acetate is most easily disposed of by controlled incineration. The management of the byproduct disposal is a tedious yet vital part of the production process however, the overall yield and turnover rate is great enough to still profit off the process while maintaining regulatory compliance. 
"""

# ╔═╡ 836e69f7-9a2d-4674-8c20-51b07d13b7ab
md"""
### References
"""

# ╔═╡ f8e863a7-76df-4a78-b86b-9aacc5490663
md"""
[1] Chameides, E. R. and B. (2008, April 17). CO2: They Should Bottle That Stuff. Time. Retrieved December 10, 2021, from http://content.time.com/time/specials/2007/article/0,28804,1730759_1731383_1731989,00.html.

[2] The Custodian. (2009, July 19). Otto Fuel II. Otto fuel II - Everything2.com. Retrieved December 11, 2021, from https://everything2.com/title/Otto+fuel+II. 

[3] D -glucose anhydrous, 96 492-62-6. Sigma Aldrich. (n.d.). Retrieved December 10, 2021, from https://www.sigmaaldrich.com/US/en/product/aldrich/158968.

[4] Environmental Protection Agency. (2021, January). Pollution Prevention and Waste Management. EPA. Retrieved December 10, 2021, from https://www.epa.gov/trinationalanalysis/pollution-prevention-and-waste-management. TRI National Analysis

[5] Hichem FETTAKA,* Michel H. LEFEBVRE. (2016). Propylene glycol dinitrate (PGDN) as an explosive taggant. Central European Journal of Energetic Materials. Retrieved December 11, 2021, from https://ipo.lukasiewicz.gov.pl/wydawnictwa/wp-content/uploads/2021/04/Fettaka-1.pdf. 

[6] National Institutes of Health. (n.d.). Ethyl acetate - disposal methods. U.S. National Library of Medicine. Retrieved December 10, 2021, from https://webwiser.nlm.nih.gov/substance?substanceId=446&identifier=Ethyl+Acetate&identifierType=name&menuItemId=59&catId=76.

[7] National Institutes of Health. (n.d.). Potassium hydroxide - disposal methods. U.S. National Library of Medicine. Retrieved December 10, 2021, from https://webwiser.nlm.nih.gov/substance?substanceId=401&identifier=Potassium+Hydroxide&identifierType=name&menuItemId=59&catId=76.

[8] Sucrose for Molecular Biology, = 99.5 GC ... - sigma-aldrich. Sigma Aldrich. (n.d.). Retrieved December 10, 2021, from https://www.sigmaaldrich.com/US/en/product/sigma/s0389. 

"""

# ╔═╡ 18b29a1a-4787-11ec-25e3-5f29ebd21430
html"""
<style>

main {
    max-width: 1200px;
    width: 85%;
    margin: auto;
    font-family: "Roboto, monospace";
}

a {
    color: blue;
    text-decoration: none;
}

.H1 {
    padding: 0px 30px;
}
</style"""

# ╔═╡ 16dca67c-f280-4a6f-bd79-308cf63dabf6
html"""
<script>

	// initialize -
	var section = 0;
	var subsection = 0;
	var headers = document.querySelectorAll('h3, h4');
	
	// main loop -
	for (var i=0; i < headers.length; i++) {
	    
		var header = headers[i];
	    var text = header.innerText;
	    var original = header.getAttribute("text-original");
	    if (original === null) {
	        
			// Save original header text
	        header.setAttribute("text-original", text);
	    } else {
	        
			// Replace with original text before adding section number
	        text = header.getAttribute("text-original");
	    }
	
	    var numbering = "";
	    switch (header.tagName) {
	        case 'H3':
	            section += 1;
	            numbering = section + ".";
	            subsection = 0;
	            break;
	        case 'H4':
	            subsection += 1;
	            numbering = section + "." + subsection;
	            break;
	    }

		// update the header text 
		header.innerText = numbering + " " + text;
	};
</script>
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BSON = "fbb218c0-5317-5bc6-957e-2ee96dd4b1f0"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
GLPK = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PrettyTables = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[compat]
BSON = "~0.3.4"
CSV = "~0.9.11"
DataFrames = "~1.3.0"
GLPK = "~0.15.2"
Optim = "~1.5.0"
Plots = "~1.25.1"
PlutoUI = "~0.7.21"
PrettyTables = "~1.2.3"
TypedTables = "~1.4.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "abb72771fd8895a7ebd83d5632dc4b989b022b5b"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.2"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "265b06e2b1f6a216e0e8f183d28e4d354eab3220"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.2.1"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[BSON]]
git-tree-sha1 = "ebcd6e22d69f21249b7b8668351ebf42d6dc87a1"
uuid = "fbb218c0-5317-5bc6-957e-2ee96dd4b1f0"
version = "0.3.4"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "365c0ea9a8d256686e97736d6b7fb0c880261a7a"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.1"

[[BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "49f14b6c56a2da47608fe30aed711b5882264d7a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.9.11"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "4c26b4e9e91ca528ea212927326ece5918a04b47"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.2"

[[ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "2e993336a3f68216be91eb8ee4625ebbaba19147"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Dictionaries]]
deps = ["Indexing", "Random"]
git-tree-sha1 = "8b8de80c4584f8525239555c95955295075beb5b"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.16"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "d8f468c5cd4d94e86816603f7d18ece910b4aaf1"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.5.0"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "04d13bfa8ef11720c24e4d840c0033d145537df7"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.17"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "8b3c09b56acaf3c0e581c66638b85c8650ee9dca"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.8.1"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "6406b5112809c08b1baa5703ad274e1dded0652f"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.23"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GLPK]]
deps = ["BinaryProvider", "CEnum", "GLPK_jll", "Libdl", "MathOptInterface"]
git-tree-sha1 = "ab6d06aa06ce3de20a82de5f7373b40796260f72"
uuid = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
version = "0.15.2"

[[GLPK_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "fe68622f32828aa92275895fdb324a85894a5b1b"
uuid = "e8aa6df9-e6ca-548a-97ff-1f85fc5b8b98"
version = "5.0.1+0"

[[GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fd75fa3a2080109a2c0ec9864a6e14c60cca3866"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.62.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "74ef6288d071f58033d54fd6708d4bc23a8b8972"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+1"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "ca99cac337f8e0561c6a6edeeae5bf6966a78d21"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "f27132e551e959b3667d8c93eae90973225032dd"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.1.1"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "JSON", "LinearAlgebra", "MutableArithmetics", "OrderedCollections", "Printf", "SparseArrays", "Test", "Unicode"]
git-tree-sha1 = "92b7de61ecb616562fd2501334f729cc9db2a9a6"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "0.10.6"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "7bb6853d9afec54019c1397c6eb610b9b9a19525"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.3.1"

[[NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "50310f934e55e5ca3912fb941dec199b49ca9b68"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.2"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "35d435b512fbab1d1a29138b5229279925eba369"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.5.0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "b084324b4af5a438cd63619fd006614b3b20b87b"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.15"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "3e7e9415f917db410dcc0a6b2b55711df434522c"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.25.1"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "b68904528fd538f1cb6a3fbc44d2abdc498f9e8e"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.21"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "db3a23166af8aebf4db5ef87ac5b00d36eb771e2"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.0"

[[PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "d940010be611ee9d67064fe559edbb305f8cc0eb"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.3"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "f45b34656397a1f6e729901dc9ef679610bd12b5"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.8"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "dec0812af1547a54105b4a6615f341377da92de6"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.0"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "e7bc80dc93f50857a5d1e3c8121495852f407e6a"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.4.0"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "0f2aa8e32d511f758a2ce49208181f7733a0936a"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.1.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[TypedTables]]
deps = ["Adapt", "Dictionaries", "Indexing", "SplitApplyCombine", "Tables", "Unicode"]
git-tree-sha1 = "f91a10d0132310a31bc4f8d0d29ce052536bd7d7"
uuid = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"
version = "1.4.0"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "66d72dc6fcc86352f01676e8f0f698562e60510f"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.23.0+0"

[[WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "c69f9da3ff2f4f02e811c3323c22e5dfcb584cfa"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.1"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─4855467c-3670-4e0b-a64e-0e09effa6e0d
# ╟─8ca99e1f-afd6-4c1c-8918-db6d9747099c
# ╟─a0ad3474-1844-41bc-bd95-242aa94a5ff1
# ╟─27d0013a-3c23-4f92-a334-5e4b55e2447e
# ╟─40da982c-1cc4-4881-a2ea-fbeef5c46d2d
# ╟─446bd227-6579-4c87-8588-0de111c5a529
# ╟─4867b51c-fb6c-42a9-b87d-4131e014b402
# ╠═059e3b4e-4e84-4934-b787-32d0f42a0247
# ╟─7410ecfc-0280-4ff2-8932-cfb2022e47c4
# ╟─d541352c-4956-4bbe-a11a-27f78f3b8afe
# ╟─538f7122-e6ae-4256-8756-cd41d27ca085
# ╟─64daa21a-ac42-4b20-9e6b-ec2d19cd50fc
# ╟─77df0589-a5a0-45cf-a0db-156621634262
# ╟─637c5a39-63db-4d76-bb4c-ecc819482036
# ╟─ae718670-bd74-48f5-96ed-d45a8d3bccb9
# ╠═3d84169a-3a85-4d9f-b7bb-b7264017fbb8
# ╟─e933ddd9-8fd8-416a-8710-a64d3eb36f79
# ╟─7d35f315-927c-44b2-948a-c4e3d273a5e1
# ╟─7720a5a6-5d7e-4c79-8aba-0a4bb04973af
# ╟─8530bb61-ab28-4747-8037-0b9d481685a7
# ╟─87e21b0b-5f6b-4402-baf3-68a150ef0fc2
# ╟─e1da943a-0d11-4776-bb67-2d8caad4cb18
# ╠═28a9763c-c5e1-41ae-b52c-445bcb839755
# ╟─24d220cd-0ead-44f1-9327-9db647b8108b
# ╟─cf367be1-ebde-4f46-974c-e2fdd1fdd903
# ╟─ea3305ae-cb8e-4a2b-83e2-ef882223e961
# ╟─77107b01-dae9-4900-b9f7-f0c0224a492b
# ╟─dcb915aa-e721-4080-a3fb-71b15d0b866d
# ╟─218fa01e-5230-49bb-a48a-ebafe81dac4a
# ╟─4030c9b7-b30d-462d-9d28-b8c2ba11a5e9
# ╟─cf16db05-b530-4693-8607-f1f45aa702cc
# ╟─22178cca-c670-4d4f-9021-22328447f9d3
# ╟─d6e3755f-8c25-4627-90a8-e056fc2b640b
# ╟─cbe36492-a695-4514-bbd8-c2df553a120d
# ╟─af08e78f-2910-47d6-a4c9-0e01ec0a7697
# ╟─eef3b8c8-410e-4880-a55e-2a09c065bef2
# ╟─7850b71d-d834-43ce-9775-77e8c6e7513b
# ╟─ab9084e1-57a2-4c6b-ad32-8fee8c142c43
# ╟─3bea3df5-a395-4831-ab43-1c713deb69f2
# ╟─836e69f7-9a2d-4674-8c20-51b07d13b7ab
# ╟─f8e863a7-76df-4a78-b86b-9aacc5490663
# ╟─18b29a1a-4787-11ec-25e3-5f29ebd21430
# ╟─16dca67c-f280-4a6f-bd79-308cf63dabf6
# ╟─0782768c-951f-4189-954d-cba8b401314d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
