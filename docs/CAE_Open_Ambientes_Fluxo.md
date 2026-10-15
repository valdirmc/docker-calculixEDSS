# CAE Open — Ambientes e Fluxo de Trabalho

Documento de referência dos ambientes Nitro (dev) e Avell (prod) para os projetos CalculiX e OpenCourant.  
**Data:** 15/10/2026

---

## Visão geral

| Máquina | Função | Branch | Caminho base |
|---------|--------|--------|--------------|
| **Nitro** | Desenvolvimento e testes | `dev` | `/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/FemEDSS/` |
| **Avell** | Operacional / produção | `prod` | `/home/valdir/000_VALDIR/00_CAE/FemEDSS/` |

---

## 1. Repositórios e branches

| Projeto | Fork | Branch Nitro | Branch Avell |
|---------|------|--------------|--------------|
| **CalculiX** | [valdirmc/docker-calculixEDSS](https://github.com/valdirmc/docker-calculixEDSS) | `dev` | `prod` |
| **OpenCourant** | [valdirmc/OpenCourantEDSS](https://github.com/valdirmc/OpenCourantEDSS) | `dev` | `prod` |

**Remotos:**
- `origin` → fork pessoal (`valdirmc/...`)
- `upstream` → repositório oficial

---

## 2. Fluxo de trabalho

```
Nitro (dev)                    Avell (prod)
    │                              │
    ├─ desenvolve / testa          │
    ├─ commit no branch dev        │
    ├─ git push origin dev         │
    │                              │
    └──── merge / cherry-pick ────►│
                                   ├─ git pull origin prod
                                   └─ usa operacionalmente
```

### Comandos típicos

**Na Nitro (após mudanças estáveis):**
```bash
git checkout dev
git add .
git commit -m "feat: descrição"
git push origin dev
```

**Na Avell (atualizar produção):**
```bash
git checkout prod
git pull origin prod
# ou, se ainda não tiver o prod local:
git fetch origin
git checkout prod
```

---

## 3. CalculiX

### 3.1 Estrutura

**Nitro (`dev`):**
```
GIT_PJR/FemEDSS/CalculiX/
├── docs/CalculiX_Ambientes_Nitro_Avell.md
├── docker-compose.yaml
├── run_ccx.sh
├── ubuntu-calculix/Dockerfile
└── .gitignore
```

**Avell (`prod`):**
```
00_CAE/FemEDSS/CalculiX/
├── docker-compose.yaml
├── run_ccx.sh
└── ubuntu-calculix/
```

### 3.2 Componentes

| Componente | Onde roda | Observação |
|------------|-----------|------------|
| `ccx` | Container Docker | Solver |
| `cgx` | Container Docker | Pré/pós (precisa display) |
| `ccx2paraview` | Host (venv) | `.frd` → `.vtu` |
| ParaView | Host | Visualização |

### 3.3 Script `run_ccx.sh`

- Pergunta antes de sobrescrever resultados.
- Roda o `ccx` no container.
- Devolve resultados para a pasta do `.inp`.
- Converte automaticamente para `.vtu`.

**Caminhos:**

| Variável | Nitro | Avell |
|----------|-------|-------|
| `COMPOSE_DIR` | `.../GIT_PJR/FemEDSS/CalculiX` | `.../00_CAE/FemEDSS/CalculiX` |
| `PYTHON_VENV` | `.../GIT_PJR/PostEDSS/venv/bin/python` | `.../00_CAE/PostEDSS/venv/bin/python` |

### 3.4 Exemplo `viga.inp`

```
*HEADING
Exemplo Simples - Viga Engastada sob Carga
*NODE
1, 0.0, 0.0, 0.0
2, 100.0, 0.0, 0.0
*ELEMENT, TYPE=B31, ELSET=ELEMENTOS_VIGA
1, 1, 2
*BEAM SECTION, ELSET=ELEMENTOS_VIGA, MATERIAL=ACO, SECTION=RECT
10.0, 20.0
0.0, 0.0, -1.0
*MATERIAL, NAME=ACO
*ELASTIC
210000.0, 0.3
*BOUNDARY
1, 1, 6, 0.0
*STEP
*STATIC
*CLOAD
2, 3, -1000.0
*NODE FILE
U
*EL FILE
S
*END STEP
```

**Nota:** `*NODE FILE` / `*EL FILE` geram o `.frd`. `*PRINT` só gera o `.dat`.

---

## 4. OpenCourant

### 4.1 Estrutura

**Nitro (`dev`):**
```
GIT_PJR/FemEDSS/OpenCourant/
```

**Avell (`prod`):**
```
00_CAE/FemEDSS/OpenCourant/
```

### 4.2 Uso (Docker)

```bash
docker run --rm -v $PWD:/work -w /work -e OMP_NUM_THREADS=4 \
  opencourant/opencourant starter -i MODELO_0000.rad -np 1

docker run --rm -v $PWD:/work -w /work -e OMP_NUM_THREADS=4 \
  opencourant/opencourant engine -i MODELO_0001.rad
```

### 4.3 Pós-processamento

- Animações `.gz` → VTKHDF via `animtovtkhdf` (Kitware)
- Visualização no ParaView

---

## 5. Pós-processamento comum

| Ferramenta | Local | Uso |
|------------|-------|-----|
| ParaView | Host (tarball) | Visualização |
| `ccx2paraview` | venv `PostEDSS/venv` | CalculiX `.frd` → `.vtu` |
| `animtovtkhdf` | venv | OpenCourant → `.vtkhdf` |

**Atalho ParaView (Nitro):**
```bash
# ~/bin/paraview
export QT_QPA_PLATFORM=xcb
nohup .../paraview-real "$@" >/dev/null 2>&1 &
```

---

## 6. Permissões e display

### Permissões (pasta examples)
```bash
sudo chown -R $USER:$USER ubuntu-calculix/examples
sudo chmod -R u+w ubuntu-calculix/examples
```

### Display para cgx
```bash
xhost +local:
# compose com network_mode: host + volume /tmp/.X11-unix
```

---

## 7. Observações

- Campo `ERROR` no `.vtu` do CalculiX é estimativa de erro, não falha.
- `ccx2paraview` 3.2.1 (GitHub) corrige bug de eigenvalues da 3.2.0.
- Docker Root Dir: `/var/lib/docker` (monitorar com `docker system df`).
- `.gitignore` ignora `examples/`, `work/`, `secret.txt` e arquivos de resultado.

---

## 8. Próximos passos

- [ ] Script de propagação automática Nitro → Avell
- [ ] Dockerfile unificado (solver + conversor) para nuvem
- [ ] Exemplos adicionais versionados (somente `.inp` / `.rad`)
- [ ] Documentação OpenCourant no mesmo padrão

---

*Documento atualizado em 15/10/2026 com estrutura de branches e fluxo de trabalho.*
