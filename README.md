# Swaying Image Filter

This script adds a new filter to [OBS](https://obsproject.com/) that can be applied to any video source (including still images or text). The filter causes the source to sway back and forth, either horizontally or vertically, following a sine curve. The distance the source sways can be defined along with its period (the time it takes to perform a complete cycle).

The filter does not move the source. Instead, it increases the size of the source by the provided range and moves the source back and forth within this frame. Negative ranges can used to crop the image into a smaller frame.

The only file that's needed is "Swaying-Image-Filter.lua". Once the file is on your local drive, the script can be imported from inside OBS by navigating to Tools -> Scripts.

This was tested on OBS version 28.0.2.

# Settings

Once you've added the "Sway" filter to a source, the following settings can be set.

**Period:** The time, in seconds, before the sway cycle repeats.

**Direction:** Decide whether the source should scroll vertically or horizontally.

**Range:** How far, in pixels, the source should scroll. Negative values will crop the source.