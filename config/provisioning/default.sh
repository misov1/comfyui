#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

# Packages are installed after nodes so we can fix them...

#DEFAULT_WORKFLOW="https://..."

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack"
    "https://github.com/comfyanonymous/ComfyUI_TensorRT"
    "https://github.com/jags111/efficiency-nodes-comfyui"
    "https://github.com/LEv145/images-grid-comfy-plugin"
    "https://github.com/SLAPaper/ComfyUI-Image-Selector"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/JPS-GER/ComfyUI_JPS-Nodes"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/misov1/ComfyUI-image-size-templet"
    "https://github.com/NyaamZ/efficiency-nodes-ED"
)

CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/1116447?type=Model&format=SafeTensor&size=full&fp=bf16&token=5fb37fbd25ef6e4438561cfde9650f12" # NoobAI-XL Epsilon-pred 1.1
    "https://civitai.com/api/download/models/1118807?type=Model&format=SafeTensor&size=pruned&fp=fp16&token=5fb37fbd25ef6e4438561cfde9650f12" # NTR Mix V777
    "https://civitai.com/api/download/models/1118881?type=Model&format=SafeTensor&size=pruned&fp=fp16&token=5fb37fbd25ef6e4438561cfde9650f12" # NTR Mix V777 LoRA#
)

LORA_MODELS=(
    "https://civitai.com/api/download/models/1031052?type=Model&format=SafeTensor&token=5fb37fbd25ef6e4438561cfde9650f12" # AI styles dump / all-in-one noob eps1.0_v1
    "https://civitai.com/api/download/models/1003884?type=Model&format=SafeTensor&token=5fb37fbd25ef6e4438561cfde9650f12" # deal360acv illust 006
    "https://civitai.com/api/download/models/1103997?type=Model&format=SafeTensor&token=5fb37fbd25ef6e4438561cfde9650f12" # nyalia illustrious
)

VAE_MODELS=(
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors"
)

UPSCALE_MODELS=(
    "https://huggingface.co/Kim2091/AnimeSharpV3/resolve/main/2x-AnimeSharpV3.pth"
)

ULTRALYTICS=(
    #"https://civitai.com/api/download/models/168820?token=5fb37fbd25ef6e4438561cfde9650f12" # eyes detailer model
)

### DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ###
function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    DISK_GB_AVAILABLE=$(($(df --output=avail -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_USED=$(($(df --output=used -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_ALLOCATED=$(($DISK_GB_AVAILABLE + $DISK_GB_USED))

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/ckpt" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/ultralytics" \
        "${ULTRALYTICS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/upscale_models" \
        "${UPSCALE_MODELS[@]}"
    provisioning_print_end
}


function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        fi
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_download() {
    wget -qnc --content-disposition --show-progress -P "$2" "$1"
}

provisioning_start
