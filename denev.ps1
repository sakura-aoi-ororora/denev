Param(
    [switch]$build,
    [switch]$runscript
)

$NVIM_LINK = "https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz"
$DATA_VOLUME = "denev-data"

Write-Output "denev: devcontainer starter for neovim"
Write-Output "version: 0.0.1"

# install nvim
$loc = Get-Location
if ( $false -eq (Test-Path "${PSScriptRoot}/data") )
{
    Write-Output "Install nvim.."
    # download nvim
    Set-Location ${PSScriptRoot}
    curl -OL $NVIM_LINK
    mkdir "data"
    tar -zxvf nvim-linux64.tar.gz --strip-components 1 -C "data"
    Remove-Item nvim-linux64.tar.gz
    Set-Location $loc
}

$data_install_flag = $false
# create volume 
if ( "$DATA_VOLUME" -cne (docker volume ls -q -f name="$DATA_VOLUME" | Select-Object -Last 1) ) 
{
    Write-Output "Create Volume.."
    $data_install_flag = $true
    docker volume create $DATA_VOLUME
}

if ($false -eq (Test-Path "${PSScriptRoot}/config") )
{
    mkdir "config"
}

# build devcontainer
if ($build)
{
    Write-Output "Build Devcontainer.."
    devcontainer build .
}

# launch devcontainer
Write-Output "Launch Devcontainer.."
$log = devcontainer up --mount "type=volume,source=${DATA_VOLUME},target=/nvim/data,external=true" --mount "type=bind,source=${PSScriptRoot}/config,target=/nvim/config"
$json = $log | Select-Object -Last 1 | ConvertFrom-Json
$outcome = $json.outcome
$cid = $json.containerId
$rfolder = $json.remoteWorkspaceFolder

if ( "success" -cne $outcome )
{
    Write-Error "Devcontainer Error"
    Write-Error $log
    exit 1
}

# copy
if ($data_install_flag)
{
    Write-Output "Copy Neovim.."
    docker cp "${PSScriptRoot}/data/." "${cid}:/nvim/data"
}

$ranscript = $false

# link
if ( "TRUE" -cne (devcontainer exec bash -c 'echo $DENEV_INIT') )
{
    Write-Output "Link Neovim & Config"
    devcontainer exec ln -s "/nvim/data/bin/nvim" "/usr/local/bin/nvim"
    devcontainer exec bash -c 'mkdir -p ~/.config && ln -s "/nvim/config" "~/.config/nvim"'
    
    # run script
    if ($true -eq (Test-Path "${PSScriptRoot}/config/denev-c.sh"))
    {
        $ranscript = $true
        Write-Output "Run Install Script.."
        devcontainer exec bash -c '. /nvim/config/denev-c.sh'
    }

    devcontainer exec bash -c 'echo export DENEV_INIT=TRUE >> ~/.bashrc'
}

# run script?
if ($runscript -eq $true -and $ranscript -eq $false -and $true -eq (Test-Path "${PSScriptRoot}/config/denev-c.sh")) {
    Write-Output "Run Install Script.."
    devcontainer exec bash -c '. /nvim/config/denev-c.sh'
}
# open bash
Write-Output "Launch bash"
docker exec -it $cid bash -c "cd ${rfolder} && bash"

# rm
Write-Output "Stop Container"
docker stop $cid
