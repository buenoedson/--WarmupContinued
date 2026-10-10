---
trigger: always_on
---

<workspace_context>
  - Especialização: Engenharia e modernização de addons em Lua para World of Warcraft.
  - Versão-alvo do client: Midnight 12.1.0 (Interface TOC confirmada para a versão).
  - Escopo de tarefas: Atualização de código legado (baseline 10.0.7), criação de novos módulos e conversão de WeakAuras para addons independentes.
  - O WeakAuras legado está descontinuado; auras convertidas devem rodar em código Lua nativo com eventos de frame da API.
</workspace_context>

<reference_sources>
  - API Reference: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
  - API Changes por Patch: https://warcraft.wiki.gg/wiki/Patch_[VERSÃO]/API_changes
  - Patches prioritários para auditoria: 10.1.0 até 12.1.0.
  - Em ausência de documentação de patch específico na wiki, declare a lacuna antes de inferir comportamento.
</reference_sources>

<rules>
  <api_integrity>
    - Proibição absoluta de alucinar APIs, namespaces `C_*`, eventos, frames ou constantes do WoW.
    - Toda assinatura de API modificada deve ser verificada contra as fontes oficiais antes do refactor.
    - Se uma API foi removida sem substituto direto: declarar explicitamente "sem equivalente confirmado" e propor solução alternativa sinalizada como não verificada.
    - Respeito estrito às políticas da Blizzard: proibir qualquer lógica que viole restrições de combate ou execute automações protegidas pelo jogo.
  </api_integrity>

  <weakauras_conversion>
    - Entradas aceitas: Tabela Lua decodificada, dump JSON ou especificação comportamental.
    - Strings seriais (`!WA:...`) só devem ser processadas se ferramentas de decodificação locais estiverem disponíveis; do contrário, solicite a tabela bruta.
    - Mapear triggers e ações customizadas para frames de eventos nativos (`CreateFrame`, `RegisterEvent`, scripts `OnEvent`/`OnUpdate`).
  </weakauras_conversion>

  <project_artifacts>
    - Em migrações completas de addons, garanta a integridade da estrutura:
      1. `[Addon].toc`: Diretiva de Interface atualizada para 12.1.0, metadados e ordem correta de carregamento.
      2. `CHANGELOG.md`: Registro público das mudanças de API em tabela (| API Antiga | Substituto | Patch | Fonte |).
      3. `README.md`: Comandos slash, dependências e limitações.
    - Não confunda `CHANGELOG.md` (artefato público do addon) com `logs/HISTORICO_SESSAO.md` (log de arquitetura interno do Antigravity).
  </project_artifacts>
</rules>