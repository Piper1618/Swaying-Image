obs = obslua
bit = require("bit")

source_def = {}
source_def.id = "swaying-image"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)

source_def.get_name = function()
	return "Sway"
end

function script_description()
	return "This adds a new filter to OBS that makes a source pan back and forth. To use it, open any source's filter menu and find the \"Sway\" filter."
end

source_def.create = function(settings, source)
	local inlineEffect = [[
		uniform float4x4 ViewProj;
		uniform texture2d image;

		uniform float xOff;
		uniform float yOff;
		uniform float xMult;
		uniform float yMult;

		sampler_state def_sampler {
			Filter   = Linear;
			AddressU = Border;
			AddressV = Border;
			BorderColor = 00000000;
		};

		struct VertInOut {
			float4 pos : POSITION;
			float2 uv  : TEXCOORD0;
		};

		VertInOut VSDefault(VertInOut vert_in)
		{
			VertInOut vert_out;
			vert_out.pos = mul(float4(vert_in.pos.xyz, 1.0), ViewProj);
			vert_out.uv  = vert_in.uv;
			return vert_out;
		}

		float4 PSAddOffset(VertInOut vert_in) : TARGET
		{
			vert_in.uv.x = (vert_in.uv.x * xMult) - xOff;
			vert_in.uv.y = (vert_in.uv.y * yMult) - yOff;
			float4 rgba = image.Sample(def_sampler, vert_in.uv);// * float4(0, 1.0, 1.0, 1.0);
			if (rgba.a > 0){
				// Because OBS multiplies the rgb values by alpha every chance it gets.
				rgba.rgb /= rgba.a;
			}
			return rgba;
		}

		technique Draw
		{
			pass
			{
				vertex_shader = VSDefault(vert_in);
				pixel_shader  = PSAddOffset(vert_in);
			}
		}
	]]

	local filter = {}
	filter.context = source
	filter.params = {}
	
	-- Internal state
	filter.xOff = 0
	filter.yOff = 0
	filter.cycle = 0
	
	obs.obs_enter_graphics()
	obs.gs_effect_destroy(filter.effect)
	filter.effect = obs.gs_effect_create(inlineEffect, "offsetEffect", nil)
	if filter.effect ~= nil then
		filter.params.xOff = obs.gs_effect_get_param_by_name(filter.effect, 'xOff')
		filter.params.yOff = obs.gs_effect_get_param_by_name(filter.effect, 'yOff')
		filter.params.xMult = obs.gs_effect_get_param_by_name(filter.effect, 'xMult')
		filter.params.yMult = obs.gs_effect_get_param_by_name(filter.effect, 'yMult')
	end
	obs.obs_leave_graphics()
	
	set_render_size(filter)

	source_def.update(filter, settings)
	return filter
end

source_def.destroy = function(filter)
	if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

function set_render_size(filter)
    target = obs.obs_filter_get_target(filter.context)

    local width, height
    if target == nil then
        width = 0
        height = 0
    else
        width = obs.obs_source_get_base_width(target)
        height = obs.obs_source_get_base_height(target)
    end

	filter.image_width = width
	filter.image_height = height
	
    filter.width = width
    filter.height = height
	
	if filter.direction == 0 then
		filter.width = math.max(width + (filter.range or 0), 0)
	else
		filter.height = math.max(height + (filter.range or 0), 0)
	end
	
end

source_def.video_render = function(filter, effect)
	obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
	
	obs.gs_effect_set_float(filter.params.xOff, filter.xOff / filter.image_width)
	obs.gs_effect_set_float(filter.params.yOff, filter.yOff / filter.image_height)
	obs.gs_effect_set_float(filter.params.xMult, filter.width / filter.image_width)
	obs.gs_effect_set_float(filter.params.yMult, filter.height / filter.image_height)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.video_tick = function(filter, deltaTime)
    set_render_size(filter)
	
	local effectivePeriod = filter.period
	
	if (effectivePeriod or 0) == 0 then effectivePeriod = 1 end
	
	filter.cycle = filter.cycle + deltaTime
	if filter.cycle > effectivePeriod then
		filter.cycle = filter.cycle - effectivePeriod
	end
	
	local t = filter.cycle / effectivePeriod * 2 * math.pi
	
	filter.xOff = 0
	filter.yOff = 0
	
	filter[(filter.direction == 0) and "xOff" or "yOff"] = (math.sin(t) + 1) / 2 * (filter.range or 0)
	
	
end

----------------------
source_def.get_properties = function(settings)
	props = obs.obs_properties_create()

	obs.obs_properties_add_float(props, "period", "Period", 0.5, 10000, 1)
	
	local list = obs.obs_properties_add_list(props, "direction", "Direction", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	obs.obs_property_list_add_int(list, "Horizontal", 0)
	obs.obs_property_list_add_int(list, "Vertical", 1)
	 
    obs.obs_properties_add_int(props, "range", "Range (can be negative)", -10000, 10000, 10)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, "period", 5)
	obs.obs_data_set_default_int(settings, "direction", 0)
    obs.obs_data_set_default_int(settings, "range", 100)
end

source_def.update = function(filter, settings)
    filter.period = obs.obs_data_get_double(settings, "period")
	filter.direction = obs.obs_data_get_int(settings, "direction")
    filter.range = obs.obs_data_get_int(settings, "range")

    set_render_size(filter)
end
-----------------------

source_def.get_width = function(filter)
	return filter.width
end

source_def.get_height = function(filter)
	return filter.height
end


obs.obs_register_source(source_def)
