param(
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    [string]$Name = "1.21.3 dynamic",
    [string]$NginxVersion = "1.21.3",
    [bool]$FullTests = $False,
    [string]$BuildMethod = "dynamic"
)

$RepoPath = [IO.Path]::Combine($pwd, $RepoName)
$TestsPath = [IO.Path]::Combine($RepoPath, "tests")
$JsExamplePath = [IO.Path]::Combine($RepoPath, "tests", "examples", "jsExample")

Write-Output 'Install perl libraries for test output formatters'

# cpan will ask for auto configuration first time it is run so answer 'yes'.
Write-Output y | sudo cpan
sudo cpan  App::cpanminus --notest
sudo cpanm --force TAP::Formatter::JUnit --notest

$ParsedVersion = [System.Version]::Parse($NginxVersion)

if ($ParsedVersion -le [System.Version]::Parse("1.19.5")) {
    $TestCommit = "6bf30e564c06b404876f0bd44ace8431b3541f24"
}
elseif ($ParsedVersion -le [System.Version]::Parse("1.23.2")) {
    $TestCommit = "3356f91a3fdae372d0946e4c89a9413f558c8017"
}
else {
    $TestCommit = $Null
}


Write-Output "Moving into $TestsPath"
Push-Location $TestsPath

try {

    Write-Output "Clean any existing nginx-tests folder."
    if (Test-Path -Path nginx-tests) {

        Remove-Item nginx-tests -Recurse -Force

    }

    Write-Output "Clone the nginx-tests source."
    git clone https://github.com/nginx/nginx-tests.git

    Write-Output "Moving into nginx-tests."
    Push-Location nginx-tests

    try {

        if ($Null -eq $TestCommit) {

            Write-Output "Checkout to before the breaking changes for this version."
            git reset --hard $TestCommit
            
        }
        
    }
    finally {

        Pop-Location

    }

}
finally {

    Pop-Location

}

if ($FullTests -eq $True) {
    Write-Output "Uninstall existing Nginx"
    sudo apt-get purge nginx -y

    Write-Output "Create ssl directory for Nginx Plus"
    sudo mkdir -p /etc/ssl/nginx

    Write-Output "Copy the nginx-repo.* file to the created directory"
    sudo cp $([IO.Path]::Combine($RepoPath, "nginx-repo.key")) /etc/ssl/nginx
    sudo cp $([IO.Path]::Combine($RepoPath, "nginx-repo.crt")) /etc/ssl/nginx

    Write-Output "Download and add NGINX signing key and App-protect security updates signing key:"
    curl -O https://nginx.org/keys/nginx_signing.key && sudo apt-key add ./nginx_signing.key

    Write-Output "Install apt utils"
    sudo apt-get install apt-transport-https lsb-release ca-certificates wget gnupg2 ubuntu-keyring

    Write-Output "Add Nginx Plus repository"
    # Add allow-insecure because there is an issue with the signing of the NGINX Plus repository.
    printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg allow-insecure=yes] https://pkgs.nginx.com/plus/ubuntu $(lsb_release -cs) nginx-plus\n" | sudo tee /etc/apt/sources.list.d/nginx-plus.list
    
    Write-Output "Download nginx-plus apt configuration files to /etc/apt/apt.conf.d"
    sudo wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx
    
    Write-Output "Update the repository and install Nginx Plus"
    sudo apt-get update
    sudo apt-get install nginx-plus -y --allow-unauthenticated

    Write-Output "Check if installation successfully"
    if (Test-Path "/usr/sbin/nginx") {

        /usr/sbin/nginx -v 2>&1 | grep -c $NginxVersion

        if ($LASTEXITCODE -ne 0) {

            Write-Error "Failed to install Nginx Plus $NginxVersion"
            exit $LASTEXITCODE

        }

        Write-output 'Nginx plus verson'
        /usr/sbin/nginx -v

    }
    else {
        
        Write-Error "Failed to install Nginx Plus $NginxVersion"
        exit 1

    }

}

Write-Output "Moving into $JsExamplePath"
Push-Location $JsExamplePath

try {
    Write-Output "Install Microsoft Edge"
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge-stable.list'
    sudo rm microsoft.gpg

    sudo apt-get update
    sudo apt-get install microsoft-edge-stable -y

    Write-Output "Get version of edge installed"
    if ($(Test-Path -Path "/opt/microsoft/msedge/msedge") -eq $False) {

        Write-output 'Can not find Edge Stable executable.'
        exit 1

    }
    $EdgeVersion = $(/opt/microsoft/msedge/msedge --product-version)

    Write-output "Download the driver for microsoft edge"
    mkdir driver
    Push-Location driver
    try {
        wget https://msedgewebdriverstorage.blob.core.windows.net/edgewebdriver/$EdgeVersion/edgedriver_linux64.zip
        Expand-Archive edgedriver_linux64.zip
    }
    finally {
        Pop-Location
    }

    Write-Output "Install Apache dev for performance tests"
    sudo apt-get update -y
    sudo apt-get install cmake apache2-dev libapr1-dev libaprutil1-dev -y

}
finally {

    Pop-Location

}

Write-Output "Installing NGINX dependencies"
sudo apt-get install make zlib1g-dev libpcre3 libpcre3-dev
