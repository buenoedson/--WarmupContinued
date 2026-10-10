Warmup Continued
A modern update to the classic addon that measures addon loading times and memory usage for World of Warcraft.

The report frame automatically opens on a fresh login (if you are not in combat).
Type /wuc, /warmupcontinued, /warmup or /wu to open or close the frame again later.

Scroll with the mousewheel. Hold Shift to scroll to the top or bottom. Hold Ctrl to scroll a full page up or down.

⚠️ Important Performance Warning ⚠️
This is a diagnostic tool designed for addon developers or users troubleshooting their UI. It should not be left enabled all the time.

The process of hooking into every addon's loading process and forcing Lua's garbage collection (collectgarbage) to measure memory has a significant impact on loading screen times and performance.

Usage: Enable it when you need to diagnose your addons, then disable it for normal gameplay.

Features of This "Continued" Version
Fully Updated: Works with modern World of Warcraft, including The War Within (11.0.2+).

Modernized API: Uses current APIs for UI creation (BackdropTemplateMixin) and slash commands, removing deprecated code to ensure future compatibility.

Clean Codebase: All new and modified code is commented in English for easier maintenance and understanding.

New Profile: Uses a new SavedVariables profile (WarmupContinuedSV) to prevent conflicts with any older versions of Warmup you might have used.

Installation
Since this is a community-updated version, it is not available on standard addon repositories. You must install it manually.

Navigate to your World of Warcraft installation folder.

Go to _retail_ -> Interface -> AddOns.

Create a new folder and name it !!WarmupContinued. The !! prefix is recommended to ensure it loads before other addons, which is critical for its function.

Place the following files inside the !!WarmupContinued folder:

!!WarmupContinued.toc

WarmupContinued.lua

History & Credits
This addon stands on the shoulders of giants. Credit goes to the previous authors who have maintained it over the years.

Original version: Tekkub

Cataclysm updates: Cybelorias/Dridzt

Further updates: Phanx

Fixed for WoW 7.1: tomchapin

This "Continued" version for modern WoW (11.0.2+): Updated by Gemini.