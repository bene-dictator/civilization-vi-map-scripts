------------------------------------------------------------------------------
--	FILE:	 AustraliaMap.lua
--	AUTHOR:  
--	PURPOSE: Creates a Tiny map shaped like real-world Australia
------------------------------------------------------------------------------
--	Copyright (c) 2014 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include "MapEnums"
include "MapUtilities"
include "MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "TerrainGenerator"
include "NaturalWonderGenerator"
include "ResourceGenerator"
include "AssignStartingPlots"

local g_iW, g_iH;
local g_iFlags = {};
local g_continentsFrac = nil;
local g_iNumTotalLandTiles = 0; 
local g_CenterX = 28;
local g_CenterY = 24;

-------------------------------------------------------------------------------
function GenerateMap()
	print("Generating Australia Map");
	local pPlot;

	-- Set globals
	g_iW, g_iH = Map.GetGridSize();
	g_iFlags = TerrainBuilder.GetFractalFlags();
	local temperature = 0;
	
	plotTypes = GeneratePlotTypes();
	terrainTypes = GenerateTerrainTypesAustralia(plotTypes, g_iW, g_iH, g_iFlags, true);

	for i = 0, (g_iW * g_iH) - 1, 1 do
		pPlot = Map.GetPlotByIndex(i);
		if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
			terrainTypes[i] = terrainTypes[i] + 1;
		end
		TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
	end

	-- Override plots around original colony of Sydney
	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do
			local i = iY * g_iW + iX;
			pPlot = Map.GetPlotByIndex(i);
			if (iX == 50 and iY == 9) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_HILLS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 50 and iY == 10) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 51 and iY == 10) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_HILLS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 50 and iY == 11) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 51 and iY == 11) then  -- This is Sydney location exactly
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 51 and iY == 12) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_HILLS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 52 and iY == 12) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 51 and iY == 13) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			elseif (iX == 52 and iY == 13) then
				terrainTypes[i] = g_TERRAIN_TYPE_GRASS_HILLS;
				TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
			end
		end
	end

	-- Temp
	AreaBuilder.Recalculate();
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());

	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	AddRivers();
	
	-- Lakes would interfere with rivers, causing them to stop and not reach the ocean, if placed any sooner.
	local numLargeLakes = math.ceil(GameInfo.Maps[Map.GetMapSize()].Continents * 1.5);
	AddLakes(numLargeLakes);

	AddFeatures();
	
	print("Adding cliffs");
	AddCliffs(plotTypes, terrainTypes);
	
	local args = {
		numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders,
	};

	local nwGen = NaturalWonderGenerator.Create(args);

	AreaBuilder.Recalculate();
	TerrainBuilder.AnalyzeChokepoints();
	TerrainBuilder.StampContinents();
	
	resourcesConfig = MapConfiguration.GetValue("resources");
	local args = {
		resources = resourcesConfig,
		LuxuriesPerRegion = 7,
	}
	local resGen = ResourceGenerator.Create(args);

	local iX = 52;
	local iY = 10;
	pPlot = Map.GetPlotByIndex(iY * g_iW + iX);
	Players[0]:SetStartingPlot(pPlot);

	iX = 52;
	iY = 11;
	pPlot = Map.GetPlotByIndex(iY * g_iW + iX);
	Players[1]:SetStartingPlot(pPlot);

	iX = 53;
	iY = 12;
	pPlot = Map.GetPlotByIndex(iY * g_iW + iX);
	Players[2]:SetStartingPlot(pPlot);

	iX = 52;
	iY = 13;
	pPlot = Map.GetPlotByIndex(iY * g_iW + iX);
	Players[3]:SetStartingPlot(pPlot);

	iX = 51;
	iY = 11;
	pPlot = Map.GetPlotByIndex(iY * g_iW + iX);
	Players[4]:SetStartingPlot(pPlot);

	local GoodyGen = AddGoodies(g_iW, g_iH);
end

-- Input a Hash; Export width, height, and wrapX
function GetMapInitData(MapSize)
	local Width = 58;
	local Height = 44;
	local WrapX = false;
	return {Width = Width, Height = Height, WrapX = WrapX,}
end
-------------------------------------------------------------------------------
function GeneratePlotTypes()
	print("Generating Plot Types");
	local plotTypes = {};

	-- Start with it all as water
	for x = 0, g_iW - 1 do
		for y = 0, g_iH - 1 do
			local i = y * g_iW + x;
			local pPlot = Map.GetPlotByIndex(i);
			plotTypes[i] = g_PLOT_TYPE_OCEAN;
			TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_OCEAN);
		end
	end

	-- Each land strip is defined by: Y, X Start, X End
	local xOffset = 2;
	local yOffset = 2;
	local landStrips = {
	{2, 37, 43},
	{3, 35, 46},
	{4, 35, 46},
	{5, 34, 46},
	{6, 6, 9},
	{6, 34, 48},
	{7, 5, 9},
	{7, 29, 29},
	{7, 32, 48},
	{8, 6, 15},
	{8, 29, 31},
	{8, 33, 49},
	{9, 5, 16},
	{9, 28, 49},
	{10, 5, 20},
	{10, 26, 50},
	{11, 4, 50},
	{12, 4, 51},
	{13, 4, 51},
	{14, 3, 52},
	{15, 2, 51},
	{16, 2, 52},
	{17, 2, 51},
	{18, 2, 52},
	{19, 1, 51},
	{20, 1, 51},
	{21, 1, 49},
	{22, 1, 49},
	{23, 2, 47},
	{24, 4, 47},
	{25, 6, 46},
	{26, 10, 46},
	{27, 11, 43},
	{28, 12, 44},
	{29, 12, 43},
	{30, 12, 12},
	{30, 14, 34},
	{30, 38, 43},
	{31, 15, 32},
	{31, 38, 42},
	{32, 16, 30},
	{32, 38, 43},
	{33, 16, 19},
	{33, 22, 29},
	{33, 38, 42},
	{34, 18, 18},
	{34, 22, 30},
	{34, 38, 40},
	{35, 22, 30},
	{35, 38, 40},
	{36, 23, 31},
	{36, 39, 40},
	{37, 26, 26},
	{37, 38, 39},
	{38, 39, 39}};
		
	for i, v in ipairs(landStrips) do
		local y = v[1] + yOffset;
		local xStart = v[2] + xOffset;
		local xEnd = v[3] + xOffset;
		for x = xStart, xEnd do
			local i = y * g_iW + x;
			local pPlot = Map.GetPlotByIndex(i);
			plotTypes[i] = g_PLOT_TYPE_LAND;
			TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
			g_iNumTotalLandTiles = g_iNumTotalLandTiles + 1;
		end
	end
		
	AreaBuilder.Recalculate();
	
	local args = {};
	args.world_age = world_age;
	args.iW = g_iW;
	args.iH = g_iH
	args.iFlags = g_iFlags;
	args.blendRidge = 10;
	args.blendFract = 1;
	args.extra_mountains = 4;
	plotTypes = ApplyTectonics(args, plotTypes);

	return plotTypes;
end

function InitFractal(args)

	if(args == nil) then args = {}; end

	local continent_grain = args.continent_grain or 2;
	local rift_grain = args.rift_grain or -1; -- Default no rifts. Set grain to between 1 and 3 to add rifts. - Bob
	local invert_heights = args.invert_heights or false;
	local polar = args.polar or true;
	local ridge_flags = args.ridge_flags or g_iFlags;

	local fracFlags = {};
	
	if(invert_heights) then
		fracFlags.FRAC_INVERT_HEIGHTS = true;
	end
	
	if(polar) then
		fracFlags.FRAC_POLAR = true;
	end
	
	if(rift_grain > 0 and rift_grain < 4) then
		local riftsFrac = Fractal.Create(g_iW, g_iH, rift_grain, {}, 6, 5);
		g_continentsFrac = Fractal.CreateRifts(g_iW, g_iH, continent_grain, fracFlags, riftsFrac, 6, 5);
	else
		g_continentsFrac = Fractal.Create(g_iW, g_iH, continent_grain, fracFlags, 6, 5);	
	end

	-- Use Brian's tectonics method to weave ridgelines in to the continental fractal.
	-- Without fractal variation, the tectonics come out too regular.
	--
	--[[ "The principle of the RidgeBuilder code is a modified Voronoi diagram. I 
	added some minor randomness and the slope might be a little tricky. It was 
	intended as a 'whole world' modifier to the fractal class. You can modify 
	the number of plates, but that is about it." ]]-- Brian Wade - May 23, 2009
	--
	local MapSizeTypes = {};
	for row in GameInfo.Maps() do
		MapSizeTypes[row.MapSizeType] = row.PlateValue;
	end
	local sizekey = Map.GetMapSize();

	local numPlates = MapSizeTypes[sizekey] or 4

	-- Blend a bit of ridge into the fractal.
	-- This will do things like roughen the coastlines and build inland seas. - Brian

	g_continentsFrac:BuildRidges(numPlates, {}, 1, 2);
end

function AddFeatures()
	print("Adding Features");

	-- Get Rainfall setting input by user.
	local rainfall = MapConfiguration.GetValue("rainfall");
	if rainfall == 4 then
		rainfall = 1 + TerrainBuilder.GetRandomNumber(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rainfall}
	local featuregen = FeatureGenerator.Create(args);

	featuregen:AddFeatures();
	
	-- Only keep floodplain far away from continent center
	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do
			local index = (iY * g_iW) + iX;
			local plot = Map.GetPlot(iX, iY);
			if (plot:GetFeatureType() == g_FEATURE_FLOODPLAINS) then
				local iDistanceFromCenter = Map.GetPlotDistance (iX, iY, g_CenterX, g_CenterY);

				-- 50/50 chance to add floodplains when get 20 tiles out.  Linear scale out to there
				if (TerrainBuilder.GetRandomNumber(40, "Resource Placement Score Adjust") >= iDistanceFromCenter) then
					TerrainBuilder.SetFeatureType(plot, -1);
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function GenerateTerrainTypesAustralia(plotTypes, iW, iH, iFlags, bNoCoastalMountains)
	print("Generating Terrain Types");
	local terrainTypes = {};

	local fracXExp = -1;
	local fracYExp = -1;
	local grain_amount = 3;

	deserts = Fractal.Create(iW, iH, 
									grain_amount, iFlags, 
									fracXExp, fracYExp);
									
	iDesertTop = deserts:GetHeight(125);   -- over 100 due to adjustment for proximity to center of continent
	iDesertBottom = deserts:GetHeight(40);

	plains = Fractal.Create(iW, iH, 
									grain_amount, iFlags, 
									fracXExp, fracYExp);
																		
	iPlainsTop = plains:GetHeight(100);
	iPlainsBottom = plains:GetHeight(35);

	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			if (plotTypes[index] == g_PLOT_TYPE_OCEAN) then
				if (IsAdjacentToLand(plotTypes, iX, iY)) then
					terrainTypes[index] = g_TERRAIN_TYPE_COAST;
				else
					terrainTypes[index] = g_TERRAIN_TYPE_OCEAN;
				end
			end
		end
	end

	if (bNoCoastalMountains == true) then
		plotTypes = RemoveCoastalMountains(plotTypes, terrainTypes);
	end

	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;

			local iDistanceFromCenter = Map.GetPlotDistance (iX, iY, g_CenterX, g_CenterY);

			if (plotTypes[index] == g_PLOT_TYPE_MOUNTAIN) then
				terrainTypes[index] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;

				local desertVal = deserts:GetHeight(iX, iY) - iDistanceFromCenter + 25;
				local plainsVal = plains:GetHeight(iX, iY);
				if ((desertVal >= iDesertBottom) and (desertVal <= iDesertTop)) then
					terrainTypes[index] = g_TERRAIN_TYPE_DESERT_MOUNTAIN;
				elseif ((plainsVal >= iPlainsBottom) and (plainsVal <= iPlainsTop)) then
					terrainTypes[index] = g_TERRAIN_TYPE_PLAINS_MOUNTAIN;
				end

			elseif (plotTypes[index] ~= g_PLOT_TYPE_OCEAN) then
				terrainTypes[index] = g_TERRAIN_TYPE_GRASS;
				
				local desertVal = deserts:GetHeight(iX, iY) - iDistanceFromCenter + 25;
				local plainsVal = plains:GetHeight(iX, iY);
				if ((desertVal >= iDesertBottom) and (desertVal <= iDesertTop)) then
					terrainTypes[index] = g_TERRAIN_TYPE_DESERT;
				elseif ((plainsVal >= iPlainsBottom) and (plainsVal <= iPlainsTop)) then
					terrainTypes[index] = g_TERRAIN_TYPE_PLAINS;
				end
			end
		end
	end

	local bExpandCoasts = true;

	if bExpandCoasts == false then
		return
	end

	print("Expanding coasts");
	for iI = 0, 2 do
		local shallowWaterPlots = {};
		for iX = 0, iW - 1 do
			for iY = 0, iH - 1 do
				local index = (iY * iW) + iX;
				if (terrainTypes[index] == g_TERRAIN_TYPE_OCEAN) then
					-- Chance for each eligible plot to become an expansion is 1 / iExpansionDiceroll.
					-- Default is two passes at 1/4 chance per eligible plot on each pass.
					if (IsAdjacentToShallowWater(terrainTypes, iX, iY) and TerrainBuilder.GetRandomNumber(4, "add shallows") == 0) then
						table.insert(shallowWaterPlots, index);
					end
				end
			end
		end
		for i, index in ipairs(shallowWaterPlots) do
			terrainTypes[index] = g_TERRAIN_TYPE_COAST;
		end
	end
	
	return terrainTypes; 
end
------------------------------------------------------------------------------
function FeatureGenerator:AddIceAtPlot(plot, iX, iY, lat)
	return
end

------------------------------------------------------------------------------
function CustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots)

	-- First check this plot itself
	if (not TerrainBuilder.CanHaveFeature(pPlot, eFeatureType, true)) then
		return false;
	else
		table.insert(aPlots, pPlot:GetIndex());
	end

	-- Which type of custom placement is it?
	local customPlacement = GameInfo.Features[eFeatureType].CustomPlacement;

	-- 6 tiles in a straight line
	if (customPlacement == "PLACEMENT_REEF_EXTENDED") then

		for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local pPlots = {};
			local iNumFound = 1;	
			local bBailed = false;			
			pPlots[iNumFound] = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
			if (pPlots[iNumFound] ~= nil and TerrainBuilder.CanHaveFeature(pPlots[iNumFound], eFeatureType, true)) then

				while iNumFound < 5 do
					iNumFound = iNumFound + 1;
					pPlots[iNumFound] = Map.GetAdjacentPlot(pPlots[iNumFound - 1]:GetX(), pPlots[iNumFound - 1]:GetY(), i);
					if (pPlots[iNumFound] == nil) then
						bBailed = true;
						break;
					elseif not TerrainBuilder.CanHaveFeature(pPlots[iNumFound], eFeatureType, true) then
						bBailed = true;
						break;
					end
				end

				if not bBailed then
					for j = 1, 5 do
						table.insert(aPlots, pPlots[j]:GetIndex());
					end
					print ("Found valid Extended Barrier Reef location at: " .. tostring(pPlot:GetX()) .. ", " .. tostring(pPlot:GetY()));
					return true;
				end
			end
		end
	end

	return false;
end
