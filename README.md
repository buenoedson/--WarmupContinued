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
- **Fully Updated:** Works with modern World of Warcraft Retail (11.x and 12.1.0 Midnight).
- **Graphical Dashboard:** Bar charts comparing load times across all installed addons, with separate breakdown for Blizzard built-in addons.
- **Load Time History:** Hover over any addon to see a 20-load performance graph. View overall game load history across the last 50 sessions.
- **Copy to Clipboard:** Dedicated text export mode to easily copy diagnostic timings.
- **UI Scaling:** Customizable scale slider from 60% to 140%.
- **Optional GC Profiling:** Garbage collection profiling is disabled by default for lightning-fast logins; toggle "Enable GC" on when detailed retained vs garbage memory breakdown is needed.
- **Addon Compartment:** Integrated with modern minimap Addon Compartment menu.
- **Zero UI Taint:** Uses Blizzard's secure hook functions (`hooksecurefunc`) to ensure full combat and protected UI stability.
- **Isolated Profile:** Uses `WarmupContinuedSV` to prevent conflicts with legacy WarmUp data.

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