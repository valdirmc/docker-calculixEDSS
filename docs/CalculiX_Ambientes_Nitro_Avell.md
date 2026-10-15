# CalculiX — Ambientes Nitro (Dev) e Avell (Operacional)

Documento de referência do projeto CalculiX na estrutura EDSS.  
**Data:** 15/10/2026

---

## Visão geral

| Máquina | Função | Caminho base |
|---------|--------|--------------|
| **Nitro** | Desenvolvimento e testes | `/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/FemEDSS/CalculiX` |
| **Avell** | Operacional / produção | `/home/valdir/000_VALDIR/00_CAE/FemEDSS/CalculiX` |

**Fluxo:** desenvolvimento e validação na Nitro → propagação para a Avell quando estável.

---

## 1. Estrutura de pastas

### Nitro (Dev)
```
/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/FemEDSS/CalculiX/
├── docker-compose.yaml
├── Dockerfile (ubuntu-calculix/)
├── run-compose.sh
├── docker-in.sh
├── run_ccx.sh
├── secret.txt
└── ubuntu-calculix/
    └── examples/
        └── viga/
            ├── viga.inp
            ├── viga.frd
            └── viga.vtu
```

### Avell (Operacional)
```
/home/valdir/000_VALDIR/00_CAE/FemEDSS/CalculiX/
├── docker-compose.yaml
├── run_ccx.sh
├── secret.txt
└── ubuntu-calculix/
    └── examples/
```

**Pós-processamento (ambas):**
- venv do `ccx2paraview`: `PostEDSS/venv`
- ParaView: tarball em `PostEDSS/` + atalho `~/bin/paraview`

---

## 2. Componentes

| Componente | Onde roda | Observação |
|------------|-----------|------------|
| CalculiX (`ccx`) | Container Docker | Solver |
| CalculiX GraphiX (`cgx`) | Container Docker | Pré/pós (precisa de display) |
| `ccx2paraview` | Host (venv) | Converte `.frd` → `.vtu` |
| ParaView | Host | Visualização |

---

## 3. Setup do container (comum às duas máquinas)

### 3.1 Clonar
```bash
git clone https://github.com/calculix/docker-calculix.git
cd docker-calculix
```

### 3.2 `secret.txt`
```bash
echo "sua_senha" > secret.txt
```

### 3.3 `docker-compose.yaml` (versão usada)
```yaml
services:
  ubuntu:
    container_name: ubuntu-calculix
    build: ubuntu-calculix
    user: ubuntu
    working_dir: /home/ubuntu
    command: /bin/bash
    tty: true
    network_mode: host
    volumes:
      - ./ubuntu-calculix/examples:/home/ubuntu/examples
      - /tmp/.X11-unix:/tmp/.X11-unix
    environment:
      - DISPLAY=${DISPLAY}
    secrets:
      - user_password

secrets:
  user_password:
    file: secret.txt
```

### 3.4 Adicionar `cgx` no Dockerfile
No `ubuntu-calculix/Dockerfile`, incluir:
```dockerfile
RUN apt-get update -y && apt-get install -y calculix-cgx && \
    rm -rf /var/lib/apt/lists/*
```

### 3.5 Subir
```bash
xhost +local:
./run-compose.sh
./docker-in.sh   # para entrar
```

---

## 4. Pós-processamento no host

### 4.1 venv + ccx2paraview
```bash
python3 -m venv PostEDSS/venv
source PostEDSS/venv/bin/activate
pip install vtk
pip install git+https://github.com/calculix/ccx2paraview.git
```

### 4.2 ParaView
- **Nitro:** tarball em `GIT_PJR/PostEDSS/` + atalho `~/bin/paraview` (usa `paraview-real` + `QT_QPA_PLATFORM=xcb` + `nohup`)
- **Avell:** tarball já configurado com `paraview.sh`

---

## 5. Script de execução (`run_ccx.sh`)

### Comportamento
1. Pergunta se deseja sobrescrever resultados existentes.
2. Sobe o container se necessário.
3. Copia o `.inp` para o container e roda o `ccx`.
4. Copia os resultados (`.frd`, `.dat`, etc.) de volta para a pasta do `.inp`.
5. Converte automaticamente para `.vtu` com `ccx2paraview`.

### Caminhos por máquina

| Variável | Nitro | Avell |
|----------|-------|-------|
| `COMPOSE_DIR` | `/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/FemEDSS/CalculiX` | `/home/valdir/000_VALDIR/00_CAE/FemEDSS/CalculiX` |
| `PYTHON_VENV` | `.../GIT_PJR/PostEDSS/venv/bin/python` | `.../00_CAE/PostEDSS/venv/bin/python` |

### Uso
```bash
./run_ccx.sh caminho/para/arquivo.inp
```

---

## 6. Exemplo de teste (`viga.inp`)

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

**Importante:** `*NODE FILE` / `*EL FILE` geram o `.frd`. `*NODE PRINT` / `*EL PRINT` só geram o `.dat`.

---

## 7. Visualização

### No ParaView
```bash
paraview caminho/para/viga.vtu
```
- Apply → Coloring: `U` → Representation: Surface
- Filtro **Warp By Vector** (campo `U`) para amplificar a deformação.

### No cgx (dentro do container)
```bash
cd ~/examples/viga
cgx viga.frd
# plot f all
# view disp
# scal d 100
# quit
```

---

## 8. Permissões

Se a pasta `examples` ficar com cadeado:
```bash
sudo chown -R $USER:$USER ubuntu-calculix/examples
sudo chmod -R u+w ubuntu-calculix/examples
```

---

## 9. Observações

- O campo `ERROR` no `.vtu` é uma estimativa de erro do CalculiX, não uma falha.
- O `ccx2paraview` 3.2.1 (GitHub) corrige o bug de eigenvalues complexos da 3.2.0.
- Docker Root Dir padrão: `/var/lib/docker` (monitorar com `docker system df`).
- Display: `network_mode: host` + `xhost +local:` + volume do X11.

---

## 10. Próximos passos possíveis

- [ ] Script de propagação Nitro → Avell
- [ ] Dockerfile único com `ccx` + `ccx2paraview` (para nuvem)
- [ ] Exemplos adicionais em `examples/`
- [ ] Integração com o fluxo OpenCourant

---

*Documento gerado a partir da implantação realizada em 15/10/2026.*
