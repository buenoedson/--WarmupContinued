# Changelog - Warmup Continued

## [v12.1.0] - 2026-10-10

### Novas Funcionalidades
- **Painel Gráfico Consolidado:** Gráficos de barras comparando tempo de carregamento de todos os addons instalados com segregação de módulos nativos da Blizzard.
- **Curva Histórica Interativa:** Visualização em gráfico de linhas dos últimos 20 carregamentos por addon ao posicionar o mouse.
- **Rastreamento Geral de Sessões:** Histórico persistente das últimas 50 sessões de inicialização do cliente.
- **Exportação Rápida:** Modo de cópia com EditBox multilinhas para fácil extração de dados diagnósticos.
- **Dimensionamento Dinâmico:** Controle deslizante de escala de 60% a 140% com persistência em SavedVariables.
- **Controle Otimizado de Coleta de Lixo:** Opção "Enable GC" desativada por padrão para acelerar o carregamento inicial do jogo.

### Mudanças e Modernização de APIs

| API Antiga | Substituto | Patch | Fonte |
| :--- | :--- | :--- | :--- |
| `ReloadUI` (sobreposição global direta) | `hooksecurefunc("ReloadUI", ...)` | 10.0.0+ | [Warcraft Wiki - hooksecurefunc](https://warcraft.wiki.gg/wiki/API_hooksecurefunc) |
| `GetNumAddOns` | `C_AddOns.GetNumAddOns` | 10.0.0 | [Patch 10.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes) |
| `GetAddOnInfo` | `C_AddOns.GetAddOnInfo` | 10.0.0 | [Patch 10.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes) |
| `IsAddOnLoaded` | `C_AddOns.IsAddOnLoaded` | 10.0.0 | [Patch 10.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes) |
| `LoadAddOn` (global legado) | `C_AddOns.LoadAddOn` | 10.0.0 | [Patch 10.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes) |
| `SetBackdrop` sem template explícito | `BackdropTemplateMixin` / `"BackdropTemplate"` | 9.0.1 | [Patch 9.0.1/API changes](https://warcraft.wiki.gg/wiki/Patch_9.0.1/API_changes) |
| Carregador intermediário XML (`load.xml`) | Inclusão direta no manifesto `.toc` (`WarmupContinued.lua`) | 12.1.0 | Práticas recomendadas Blizzard FrameXML |
| `## X-Category` | `## Category` / `## Category-ptBR` | 10.0.0 | Sistema de Categorias do TOC Blizzard |
| Integração minimap legada | `## AddonCompartmentFunc` | 10.0.0 | Addon Compartment System |
