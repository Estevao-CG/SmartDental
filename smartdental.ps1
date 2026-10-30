<#
    SmartDental - Interface PowerShell
    Consome a API Spring Boot (pacientes, profissionais, agendamentos e atendimentos).
    Uso:  powershell -ExecutionPolicy Bypass -File .\smartdental.ps1 [-BaseUrl http://localhost:8081]
#>
param(
    [string]$BaseUrl = 'http://localhost:8081'
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch { }
Add-Type -AssemblyName System.Net.Http
$BaseUrl = $BaseUrl.TrimEnd('/')
try { $Host.UI.RawUI.WindowTitle = 'SmartDental - Interface PowerShell' } catch { }

$script:CANCEL = '__CANCELAR__'
$script:Http = New-Object System.Net.Http.HttpClient
$script:Http.Timeout = [TimeSpan]::FromSeconds(20)
$script:Inv = [System.Globalization.CultureInfo]::InvariantCulture

# Caracteres de desenho (por codigo, para nao depender da codificacao do arquivo)
$B = @{
    H  = [string][char]0x2500; V  = [string][char]0x2502
    TL = [string][char]0x250C; TR = [string][char]0x2510
    BL = [string][char]0x2514; BR = [string][char]0x2518
    TM = [string][char]0x252C; BM = [string][char]0x2534
    LM = [string][char]0x251C; RM = [string][char]0x2524
    X  = [string][char]0x253C
    DH = [string][char]0x2550; DTL = [string][char]0x2554; DTR = [string][char]0x2557
    DBL = [string][char]0x255A; DBR = [string][char]0x255D
}

# ============================================================
#  MENSAGENS E TELA
# ============================================================
function Msg-Ok    { param([string]$T) Write-Host ('  [OK] '   + $T) -ForegroundColor Green }
function Msg-Erro  { param([string]$T) Write-Host ('  [ERRO] ' + $T) -ForegroundColor Red }
function Msg-Aviso { param([string]$T) Write-Host ('  [!] '    + $T) -ForegroundColor Yellow }
function Msg-Info  { param([string]$T) Write-Host ('  [i] '    + $T) -ForegroundColor Cyan }

function Wait-Enter {
    Write-Host ''
    Write-Host '  Pressione ENTER para continuar...' -ForegroundColor DarkGray
    [void](Read-Host)
}

function Write-CenterLine {
    param([string]$Text, [string]$Color = 'White', [int]$Width = 70)
    $left = [int][math]::Floor(($Width - $Text.Length) / 2)
    if ($left -lt 0) { $left = 0 }
    $content = ((' ' * $left) + $Text).PadRight($Width)
    Write-Host '  ' -NoNewline
    Write-Host $B.DV -NoNewline -ForegroundColor Cyan
    Write-Host $content -NoNewline -ForegroundColor $Color
    Write-Host $B.DV -ForegroundColor Cyan
}

function Show-Banner {
    param([string]$Path = 'Menu principal')
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $B.DTL + ($B.DH * 70) + $B.DTR) -ForegroundColor Cyan
    Write-CenterLine 'S M A R T D E N T A L' 'Green'
    Write-CenterLine 'Sistema de Atendimento Odontológico' 'White'
    Write-Host ('  ' + $B.DBL + ($B.DH * 70) + $B.DBR) -ForegroundColor Cyan
    Write-Host ('  Local: ' + $Path) -ForegroundColor Yellow
    Write-Host ('  API:   ' + $BaseUrl) -ForegroundColor DarkGray
    Write-Host ''
}

function Show-MenuItems {
    param([object[]]$Items)
    foreach ($it in $Items) {
        $color = 'White'
        if ($it[0] -eq '0') { $color = 'DarkYellow' }
        Write-Host '   [' -NoNewline -ForegroundColor DarkGray
        Write-Host $it[0] -NoNewline -ForegroundColor Cyan
        Write-Host '] ' -NoNewline -ForegroundColor DarkGray
        Write-Host $it[1] -ForegroundColor $color
    }
}

function Read-Line {
    $v = Read-Host
    if ($null -eq $v) { return '' }
    return $v.Trim()
}

function Read-Choice {
    param([string[]]$Valid)
    while ($true) {
        Write-Host ''
        Write-Host '  Escolha uma opção: ' -NoNewline -ForegroundColor Yellow
        $c = Read-Line
        if ($Valid -contains $c) { return $c }
        Msg-Aviso 'Opção inválida. Tente novamente.'
    }
}

function Test-Cancel { param($Value) return (($Value -is [string]) -and ($Value -eq $script:CANCEL)) }

function Invoke-Safe {
    param([scriptblock]$Block)
    try { & $Block }
    catch {
        Write-Host ''
        Msg-Erro ('Ocorreu um erro inesperado: ' + $_.Exception.Message)
        Wait-Enter
    }
}

# ============================================================
#  FORMATACAO
# ============================================================
function Fit {
    param($Text, [int]$Width, [string]$Align = 'L')
    $s = '-'
    if ($null -ne $Text -and ([string]$Text) -ne '') { $s = [string]$Text }
    $s = $s -replace '[\r\n\t]+', ' '
    if ($s.Length -gt $Width) { $s = $s.Substring(0, $Width - 1) + [string][char]0x2026 }
    if ($Align -eq 'R') { return $s.PadLeft($Width) }
    return $s.PadRight($Width)
}

function Format-Cpf {
    param($Value)
    $d = ([string]$Value) -replace '\D', ''
    if ($d.Length -eq 11) {
        return ('{0}.{1}.{2}-{3}' -f $d.Substring(0,3), $d.Substring(3,3), $d.Substring(6,3), $d.Substring(9,2))
    }
    return [string]$Value
}

function Format-Tel {
    param($Value)
    $d = ([string]$Value) -replace '\D', ''
    if ($d.Length -eq 11) { return ('({0}) {1}-{2}' -f $d.Substring(0,2), $d.Substring(2,5), $d.Substring(7,4)) }
    if ($d.Length -eq 10) { return ('({0}) {1}-{2}' -f $d.Substring(0,2), $d.Substring(2,4), $d.Substring(6,4)) }
    return [string]$Value
}

function Convert-ApiDate {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }
    $d = [datetime]::MinValue
    $ok = [datetime]::TryParse([string]$Value, $script:Inv, [System.Globalization.DateTimeStyles]::None, [ref]$d)
    if ($ok) { return $d }
    return $null
}

function Format-Date {
    param($Value)
    $d = Convert-ApiDate $Value
    if ($null -eq $d) { return '-' }
    return $d.ToString('dd/MM/yyyy HH:mm', $script:Inv)
}

function Show-Table {
    param([object[]]$Rows, [object[]]$Columns, [string]$EmptyMessage = 'Nenhum registro encontrado.')
    if ($null -eq $Rows -or $Rows.Count -eq 0) { Msg-Aviso $EmptyMessage; return }

    $segs = @()
    foreach ($c in $Columns) { $segs += ($B.H * ($c.W + 2)) }
    Write-Host ('  ' + $B.TL + ($segs -join $B.TM) + $B.TR) -ForegroundColor DarkGray

    Write-Host '  ' -NoNewline
    Write-Host $B.V -NoNewline -ForegroundColor DarkGray
    foreach ($c in $Columns) {
        $align = 'L'; if ($c.A) { $align = $c.A }
        Write-Host (' ' + (Fit $c.H $c.W $align) + ' ') -NoNewline -ForegroundColor Cyan
        Write-Host $B.V -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host ('  ' + $B.LM + ($segs -join $B.X) + $B.RM) -ForegroundColor DarkGray

    foreach ($row in $Rows) {
        Write-Host '  ' -NoNewline
        Write-Host $B.V -NoNewline -ForegroundColor DarkGray
        foreach ($c in $Columns) {
            $sb = $c.E
            $v = & $sb $row
            $color = 'White'
            if ($c.C) { $cb = $c.C; $cc = & $cb $row $v; if ($cc) { $color = $cc } }
            $align = 'L'; if ($c.A) { $align = $c.A }
            Write-Host (' ' + (Fit $v $c.W $align) + ' ') -NoNewline -ForegroundColor $color
            Write-Host $B.V -NoNewline -ForegroundColor DarkGray
        }
        Write-Host ''
    }
    Write-Host ('  ' + $B.BL + ($segs -join $B.BM) + $B.BR) -ForegroundColor DarkGray
    Write-Host ('  {0} registro(s)' -f $Rows.Count) -ForegroundColor DarkGray
}

function Show-Ficha {
    param([object[]]$Pairs)
    Write-Host ('  ' + $B.TL + ($B.H * 54) + $B.TR) -ForegroundColor DarkGray
    foreach ($p in $Pairs) {
        $color = 'White'
        if ($p.Count -ge 3) { $color = $p[2] }
        Write-Host ('  ' + $B.V + ' ') -NoNewline -ForegroundColor DarkGray
        Write-Host (([string]$p[0]).PadRight(13)) -NoNewline -ForegroundColor Cyan
        Write-Host (Fit $p[1] 38 'L') -NoNewline -ForegroundColor $color
        Write-Host (' ' + $B.V) -ForegroundColor DarkGray
    }
    Write-Host ('  ' + $B.BL + ($B.H * 54) + $B.BR) -ForegroundColor DarkGray
}

# ============================================================
#  COMUNICACAO COM A API
# ============================================================
function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null)
    $result = [pscustomobject]@{ Ok = $false; Status = 0; Data = $null; Message = '' }
    try {
        $uri = $BaseUrl + $Path
        $req = New-Object -TypeName System.Net.Http.HttpRequestMessage -ArgumentList (New-Object -TypeName System.Net.Http.HttpMethod -ArgumentList $Method), $uri
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Compress
            $req.Content = New-Object -TypeName System.Net.Http.StringContent -ArgumentList $json, ([System.Text.Encoding]::UTF8), 'application/json'
        }
        $resp  = $script:Http.SendAsync($req).GetAwaiter().GetResult()
        $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $text  = ''
        if ($bytes -and $bytes.Length -gt 0) { $text = [System.Text.Encoding]::UTF8.GetString($bytes) }
        $result.Status = [int]$resp.StatusCode

        if ($resp.IsSuccessStatusCode) {
            $result.Ok = $true
            $t = $text.Trim()
            if ($t.StartsWith('{') -or $t.StartsWith('[')) {
                try { $result.Data = ($t | ConvertFrom-Json) } catch { $result.Data = $t }
            } else {
                $result.Data = $t
            }
        } else {
            $msg = $text.Trim()
            if ($msg.StartsWith('{')) {
                try {
                    $j = $msg | ConvertFrom-Json
                    if ($j.message) { $msg = [string]$j.message } elseif ($j.error) { $msg = [string]$j.error }
                } catch { }
            }
            if ($msg -eq '') { $msg = 'A API respondeu com erro HTTP ' + $result.Status + '.' }
            $result.Message = $msg
        }
    } catch {
        $result.Status = 0
        $result.Message = 'Não foi possível conectar à API em ' + $BaseUrl + '. Verifique se o backend está em execução.'
    }
    return $result
}

function Show-ApiError {
    param($R)
    Msg-Erro $R.Message
}

function Get-List {
    param([string]$Path)
    $r = Invoke-Api -Method GET -Path $Path
    if (-not $r.Ok) { Show-ApiError $r; return $null }
    if ($null -eq $r.Data) { return ,@() }
    return ,@($r.Data)
}

function Test-ApiStartup {
    while ($true) {
        Show-Banner 'Conectando...'
        Msg-Info ('Verificando a API em ' + $BaseUrl + ' ...')
        $r = Invoke-Api -Method GET -Path '/pacientes'
        if ($r.Ok) { Msg-Ok 'API online.'; Start-Sleep -Milliseconds 700; return $true }
        Show-ApiError $r
        Write-Host ''
        if (-not (Read-Confirm 'Tentar novamente')) { return $false }
    }
}

# ============================================================
#  ENTRADA DE DADOS E VALIDACOES
# ============================================================
function Read-Confirm {
    param([string]$Question)
    while ($true) {
        Write-Host ('  ' + $Question + ' (S/N): ') -NoNewline -ForegroundColor Yellow
        $r = (Read-Line).ToUpper()
        if ($r -eq 'S' -or $r -eq 'SIM') { return $true }
        if ($r -eq 'N' -or $r -eq 'NAO' -or $r -eq 'NÃO') { return $false }
        Msg-Aviso 'Responda com S ou N.'
    }
}

function Read-Input {
    param(
        [string]$Label,
        [string]$Current = '',
        [switch]$Required,
        [scriptblock]$Validator,
        [string]$Hint = ''
    )
    while ($true) {
        if ($Hint -ne '') { Write-Host ('    ' + $Hint) -ForegroundColor DarkGray }
        $suffix = ''
        if ($Current -ne '') { $suffix = ' [Enter mantém: ' + $Current + ']' }
        Write-Host ('  ' + $Label + $suffix + ': ') -NoNewline -ForegroundColor Yellow
        $v = Read-Line
        if ($v.ToLower() -eq 'cancelar') { return $script:CANCEL }
        if ($v -eq '') {
            if ($Current -ne '') { return $Current }
            if ($Required) { Msg-Erro 'Campo obrigatório.'; continue }
            return ''
        }
        if ($Validator) {
            $err = & $Validator $v
            if ($err) { Msg-Erro $err; continue }
        }
        return $v
    }
}

$ValNome = {
    param($v)
    if ($v.Length -lt 3)   { return 'O nome deve ter pelo menos 3 caracteres.' }
    if ($v.Length -gt 100) { return 'O nome deve ter no máximo 100 caracteres.' }
    if ($v -notmatch '^[\p{L}][\p{L}\s\.\-'']+$') { return 'Use apenas letras, espaços, ponto, hífen e apóstrofo.' }
}

$ValTel = {
    param($v)
    if ($v -eq '-') { return }
    $d = $v -replace '\D', ''
    if ($d.Length -ne 10 -and $d.Length -ne 11) { return 'Telefone inválido. Informe DDD + número (10 ou 11 dígitos).' }
}

$ValCro = {
    param($v)
    if ($v.Length -lt 3 -or $v.Length -gt 20) { return 'O CRO deve ter entre 3 e 20 caracteres.' }
    if ($v -notmatch '^[A-Za-z0-9\-\/\. ]+$') { return 'O CRO deve conter apenas letras, números, ponto, hífen e barra.' }
}

$ValDesc = {
    param($v)
    if ($v.Length -lt 3)   { return 'A descrição deve ter pelo menos 3 caracteres.' }
    if ($v.Length -gt 255) { return 'A descrição deve ter no máximo 255 caracteres (limite do banco).' }
}

$ValDataHora = {
    param($v)
    $d = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($v, 'dd/MM/yyyy HH:mm', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)
    if (-not $ok) { return 'Data inválida. Use o formato dd/MM/aaaa HH:mm (ex.: 10/11/2026 14:30).' }
    if ($d -le (Get-Date)) { return 'A data e hora do agendamento devem ser futuras.' }
}

function Test-CpfDigitos {
    param([string]$Cpf)
    $d = @()
    foreach ($ch in $Cpf.ToCharArray()) { $d += [int][string]$ch }
    foreach ($t in 9, 10) {
        $sum = 0
        for ($i = 0; $i -lt $t; $i++) { $sum += $d[$i] * ($t + 1 - $i) }
        $r = ($sum * 10) % 11
        if ($r -eq 10) { $r = 0 }
        if ($r -ne $d[$t]) { return $false }
    }
    return $true
}

function Read-Cpf {
    param([string]$Current = '', $Existentes = $null, $ExcludeId = $null)
    $currentDigits = $Current -replace '\D', ''
    while ($true) {
        $cur = ''
        if ($Current -ne '') { $cur = Format-Cpf $Current }
        $v = Read-Input -Label 'CPF' -Current $cur -Required -Hint 'Somente os 11 números (pontos e traço são aceitos).'
        if (Test-Cancel $v) { return $v }
        $d = $v -replace '\D', ''
        if ($d.Length -ne 11) { Msg-Erro 'O CPF deve ter exatamente 11 dígitos.'; continue }
        if ($d -match '^(\d)\1{10}$') { Msg-Erro 'CPF inválido (todos os dígitos iguais).'; continue }
        if ($d -ne $currentDigits) {
            if (-not (Test-CpfDigitos $d)) {
                Msg-Aviso 'Os dígitos verificadores deste CPF não conferem.'
                if (-not (Read-Confirm 'Usar este CPF mesmo assim')) { continue }
            }
        }
        $dup = $null
        if ($null -ne $Existentes) {
            foreach ($e in $Existentes) {
                if ($e.id -ne $ExcludeId -and (([string]$e.cpf) -replace '\D', '') -eq $d) { $dup = $e; break }
            }
        }
        if ($null -ne $dup) {
            Msg-Erro ('Este CPF já está cadastrado para ' + $dup.nome + ' (ID ' + $dup.id + ').')
            continue
        }
        return $d
    }
}

function Read-Id {
    param([string]$Label)
    $r = Read-Input -Label $Label -Required -Hint 'Digite o número do ID (ou "cancelar" para voltar).' -Validator {
        param($v)
        if ($v -notmatch '^\d{1,12}$' -or [long]$v -lt 1) { return 'ID inválido. Digite apenas números positivos.' }
    }
    if (Test-Cancel $r) { return $r }
    return [long]$r
}

# ============================================================
#  APOIO: LISTAS, TABELAS E NOMES
# ============================================================
function Get-Name {
    param($Map, $Id)
    $k = [string]$Id
    if ($Map.ContainsKey($k)) { return $Map[$k] }
    return ('(ID ' + $k + ')')
}

function Get-PacienteColumns {
    return @(
        @{ H = 'ID';       W = 5;  A = 'R'; E = { param($r) $r.id } },
        @{ H = 'Nome';     W = 28; E = { param($r) $r.nome } },
        @{ H = 'CPF';      W = 14; E = { param($r) Format-Cpf $r.cpf } },
        @{ H = 'Telefone'; W = 15; E = { param($r) Format-Tel $r.telefone } },
        @{ H = 'Situação'; W = 9;  E = { param($r) if ($r.ativo) { 'Ativo' } else { 'Inativo' } }; C = { param($r, $v) if ($r.ativo) { 'Green' } else { 'Red' } } }
    )
}

function Get-ProfissionalColumns {
    return @(
        @{ H = 'ID';   W = 5;  A = 'R'; E = { param($r) $r.id } },
        @{ H = 'Nome'; W = 32; E = { param($r) $r.nome } },
        @{ H = 'CRO';  W = 16; E = { param($r) $r.cro } }
    )
}

function Get-AgendaColumns {
    return @(
        @{ H = 'ID';           W = 5;  A = 'R'; E = { param($r) $r.Id } },
        @{ H = 'Paciente';     W = 24; E = { param($r) $r.Paciente } },
        @{ H = 'Profissional'; W = 24; E = { param($r) $r.Profissional } },
        @{ H = 'Data/Hora';    W = 16; E = { param($r) $r.Data } },
        @{ H = 'Situação';     W = 10; E = { param($r) $r.Situacao }; C = { param($r, $v) if ($v -eq 'AGENDADO') { 'Green' } elseif ($v -eq 'CANCELADO') { 'Red' } else { 'Yellow' } } }
    )
}

function Get-Maps {
    $pacs = Get-List '/pacientes'
    if ($null -eq $pacs) { return $null }
    $profs = Get-List '/profissionais'
    if ($null -eq $profs) { return $null }
    $mp = @{}
    foreach ($x in $pacs)  { $mp[[string]$x.id]  = [string]$x.nome }
    $mpr = @{}
    foreach ($x in $profs) { $mpr[[string]$x.id] = [string]$x.nome }
    return @{ Pacientes = $pacs; Profissionais = $profs; MapP = $mp; MapPr = $mpr }
}

function ConvertTo-AgendaRows {
    param($Ags, $Maps)
    $sorted = @($Ags | Sort-Object { Convert-ApiDate $_.dataHora })
    $rows = @()
    foreach ($a in $sorted) {
        $rows += [pscustomobject]@{
            Id           = $a.id
            Paciente     = (Get-Name $Maps.MapP $a.pacienteId)
            Profissional = (Get-Name $Maps.MapPr $a.profissionalId)
            Data         = (Format-Date $a.dataHora)
            Situacao     = [string]$a.situacao
            PacienteId   = $a.pacienteId
        }
    }
    return ,$rows
}

function Show-FichaPaciente {
    param($P)
    $sit = 'Inativo'; $cor = 'Red'
    if ($P.ativo) { $sit = 'Ativo'; $cor = 'Green' }
    Show-Ficha @(
        @('ID', $P.id),
        @('Nome', $P.nome),
        @('CPF', (Format-Cpf $P.cpf)),
        @('Telefone', (Format-Tel $P.telefone)),
        @('Situação', $sit, $cor)
    )
}

# ============================================================
#  PACIENTES
# ============================================================
function New-Paciente {
    Show-Banner 'Pacientes > Cadastrar'
    Write-Host '  Digite "cancelar" em qualquer campo para voltar.' -ForegroundColor DarkGray
    Write-Host ''
    $existentes = Get-List '/pacientes'
    if ($null -eq $existentes) { Wait-Enter; return }

    $nome = Read-Input -Label 'Nome completo' -Required -Validator $ValNome
    if (Test-Cancel $nome) { return }
    $cpf = Read-Cpf -Existentes $existentes
    if (Test-Cancel $cpf) { return }
    $tel = Read-Input -Label 'Telefone (opcional)' -Validator $ValTel -Hint 'DDD + número, ex.: 66999998888.'
    if (Test-Cancel $tel) { return }
    $telDigitos = $tel -replace '\D', ''

    Write-Host ''
    Show-Ficha @( @('Nome', $nome), @('CPF', (Format-Cpf $cpf)), @('Telefone', (Format-Tel $telDigitos)) )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar cadastro')) { Msg-Aviso 'Cadastro cancelado.'; Wait-Enter; return }

    $r = Invoke-Api -Method POST -Path '/pacientes' -Body @{ nome = $nome; cpf = $cpf; telefone = $telDigitos }
    Write-Host ''
    if ($r.Ok) { Msg-Ok ('Paciente cadastrado com sucesso! ID: ' + $r.Data.id) } else { Show-ApiError $r }
    Wait-Enter
}

function Show-Pacientes {
    Show-Banner 'Pacientes > Listar'
    $lista = Get-List '/pacientes'
    if ($null -eq $lista) { Wait-Enter; return }
    $lista = @($lista | Sort-Object { [string]$_.nome })
    Show-Table -Rows $lista -Columns (Get-PacienteColumns) -EmptyMessage 'Nenhum paciente cadastrado.'
    if ($lista.Count -gt 0) {
        $ativos = @($lista | Where-Object { $_.ativo }).Count
        Write-Host ('  Ativos: {0}   Inativos: {1}' -f $ativos, ($lista.Count - $ativos)) -ForegroundColor DarkGray
    }
    Wait-Enter
}

function Find-PacienteById {
    Show-Banner 'Pacientes > Buscar por ID'
    $id = Read-Id 'ID do paciente'
    if (Test-Cancel $id) { return }
    Write-Host ''
    $r = Invoke-Api -Method GET -Path ('/pacientes/' + $id)
    if ($r.Ok) { Show-FichaPaciente $r.Data } else { Show-ApiError $r }
    Wait-Enter
}

function Find-PacienteByText {
    Show-Banner 'Pacientes > Buscar por nome ou CPF'
    $t = Read-Input -Label 'Nome (ou parte) ou CPF' -Required -Hint 'A busca ignora maiúsculas e pontuação do CPF.'
    if (Test-Cancel $t) { return }
    Write-Host ''
    $lista = Get-List '/pacientes'
    if ($null -eq $lista) { Wait-Enter; return }
    $tl = $t.ToLower()
    $td = $t -replace '\D', ''
    $achados = @()
    foreach ($p in $lista) {
        $porNome = ([string]$p.nome).ToLower().Contains($tl)
        $porCpf = $false
        if ($td.Length -gt 0) { $porCpf = ((([string]$p.cpf) -replace '\D', '')).Contains($td) }
        if ($porNome -or $porCpf) { $achados += $p }
    }
    Show-Table -Rows $achados -Columns (Get-PacienteColumns) -EmptyMessage ('Nenhum paciente encontrado para "' + $t + '".')
    Wait-Enter
}

function Update-Paciente {
    Show-Banner 'Pacientes > Atualizar'
    $id = Read-Id 'ID do paciente'
    if (Test-Cancel $id) { return }
    Write-Host ''
    $r = Invoke-Api -Method GET -Path ('/pacientes/' + $id)
    if (-not $r.Ok) { Show-ApiError $r; Wait-Enter; return }
    $p = $r.Data
    Show-FichaPaciente $p
    if (-not $p.ativo) { Msg-Aviso 'Paciente inativo: a atualização não o reativa.' }
    Write-Host ''
    Write-Host '  Pressione ENTER para manter o valor atual. Digite "cancelar" para sair.' -ForegroundColor DarkGray
    Write-Host ''

    $existentes = Get-List '/pacientes'
    if ($null -eq $existentes) { Wait-Enter; return }

    $nome = Read-Input -Label 'Nome' -Current ([string]$p.nome) -Required -Validator $ValNome
    if (Test-Cancel $nome) { return }
    $cpf = Read-Cpf -Current ([string]$p.cpf) -Existentes $existentes -ExcludeId $p.id
    if (Test-Cancel $cpf) { return }
    $tel = Read-Input -Label 'Telefone' -Current (Format-Tel $p.telefone) -Validator $ValTel -Hint 'Digite "-" para apagar o telefone.'
    if (Test-Cancel $tel) { return }
    if ($tel -eq '-') { $telDigitos = '' } else { $telDigitos = $tel -replace '\D', '' }

    $igual = ($nome -eq [string]$p.nome) -and ($cpf -eq (([string]$p.cpf) -replace '\D', '')) -and ($telDigitos -eq (([string]$p.telefone) -replace '\D', ''))
    if ($igual) { Write-Host ''; Msg-Aviso 'Nenhuma alteração foi informada.'; Wait-Enter; return }

    Write-Host ''
    Show-Ficha @( @('Nome', $nome), @('CPF', (Format-Cpf $cpf)), @('Telefone', (Format-Tel $telDigitos)) )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar atualização')) { Msg-Aviso 'Atualização cancelada.'; Wait-Enter; return }

    $r2 = Invoke-Api -Method PUT -Path ('/pacientes/' + $id) -Body @{ nome = $nome; cpf = $cpf; telefone = $telDigitos }
    Write-Host ''
    if ($r2.Ok) { Msg-Ok 'Paciente atualizado com sucesso!' } else { Show-ApiError $r2 }
    Wait-Enter
}

function Disable-Paciente {
    Show-Banner 'Pacientes > Inativar'
    $id = Read-Id 'ID do paciente'
    if (Test-Cancel $id) { return }
    Write-Host ''
    $r = Invoke-Api -Method GET -Path ('/pacientes/' + $id)
    if (-not $r.Ok) { Show-ApiError $r; Wait-Enter; return }
    Show-FichaPaciente $r.Data
    Write-Host ''
    if (-not $r.Data.ativo) { Msg-Aviso 'Este paciente já está inativo.'; Wait-Enter; return }
    Msg-Aviso 'O paciente não será apagado: apenas ficará marcado como inativo.'
    if (-not (Read-Confirm 'Confirmar inativação')) { Msg-Aviso 'Operação cancelada.'; Wait-Enter; return }
    $r2 = Invoke-Api -Method DELETE -Path ('/pacientes/' + $id)
    Write-Host ''
    if ($r2.Ok) { Msg-Ok 'Paciente inativado com sucesso!' } else { Show-ApiError $r2 }
    Wait-Enter
}

function Show-MenuPacientes {
    while ($true) {
        Show-Banner 'Menu principal > Pacientes'
        Show-MenuItems @(
            @('1', 'Cadastrar paciente'),
            @('2', 'Listar pacientes'),
            @('3', 'Buscar por ID'),
            @('4', 'Buscar por nome ou CPF'),
            @('5', 'Atualizar paciente'),
            @('6', 'Inativar paciente'),
            @('0', 'Voltar')
        )
        $c = Read-Choice @('0','1','2','3','4','5','6')
        switch ($c) {
            '1' { Invoke-Safe { New-Paciente } }
            '2' { Invoke-Safe { Show-Pacientes } }
            '3' { Invoke-Safe { Find-PacienteById } }
            '4' { Invoke-Safe { Find-PacienteByText } }
            '5' { Invoke-Safe { Update-Paciente } }
            '6' { Invoke-Safe { Disable-Paciente } }
            '0' { return }
        }
    }
}

# ============================================================
#  PROFISSIONAIS
# ============================================================
function New-Profissional {
    Show-Banner 'Profissionais > Cadastrar'
    Write-Host '  Digite "cancelar" em qualquer campo para voltar.' -ForegroundColor DarkGray
    Write-Host ''
    $nome = Read-Input -Label 'Nome completo' -Required -Validator $ValNome
    if (Test-Cancel $nome) { return }
    $cro = Read-Input -Label 'CRO' -Required -Validator $ValCro -Hint 'Ex.: MT-1234'
    if (Test-Cancel $cro) { return }
    $cro = $cro.ToUpper()

    Write-Host ''
    Show-Ficha @( @('Nome', $nome), @('CRO', $cro) )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar cadastro')) { Msg-Aviso 'Cadastro cancelado.'; Wait-Enter; return }

    $r = Invoke-Api -Method POST -Path '/profissionais' -Body @{ nome = $nome; cro = $cro }
    Write-Host ''
    if ($r.Ok) { Msg-Ok ('Profissional cadastrado com sucesso! ID: ' + $r.Data.id) } else { Show-ApiError $r }
    Wait-Enter
}

function Show-Profissionais {
    Show-Banner 'Profissionais > Listar'
    $lista = Get-List '/profissionais'
    if ($null -eq $lista) { Wait-Enter; return }
    $lista = @($lista | Sort-Object { [string]$_.nome })
    Show-Table -Rows $lista -Columns (Get-ProfissionalColumns) -EmptyMessage 'Nenhum profissional cadastrado.'
    Wait-Enter
}

function Find-ProfissionalById {
    Show-Banner 'Profissionais > Buscar por ID'
    $id = Read-Id 'ID do profissional'
    if (Test-Cancel $id) { return }
    Write-Host ''
    $r = Invoke-Api -Method GET -Path ('/profissionais/' + $id)
    if ($r.Ok) { Show-Ficha @( @('ID', $r.Data.id), @('Nome', $r.Data.nome), @('CRO', $r.Data.cro) ) } else { Show-ApiError $r }
    Wait-Enter
}

function Show-MenuProfissionais {
    while ($true) {
        Show-Banner 'Menu principal > Profissionais'
        Show-MenuItems @(
            @('1', 'Cadastrar profissional'),
            @('2', 'Listar profissionais'),
            @('3', 'Buscar por ID'),
            @('0', 'Voltar')
        )
        $c = Read-Choice @('0','1','2','3')
        switch ($c) {
            '1' { Invoke-Safe { New-Profissional } }
            '2' { Invoke-Safe { Show-Profissionais } }
            '3' { Invoke-Safe { Find-ProfissionalById } }
            '0' { return }
        }
    }
}

# ============================================================
#  AGENDAMENTOS
# ============================================================
function New-Agendamento {
    Show-Banner 'Agendamentos > Novo agendamento'
    Write-Host '  Digite "cancelar" em qualquer campo para voltar.' -ForegroundColor DarkGray
    Write-Host ''
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }

    $ativos = @($maps.Pacientes | Where-Object { $_.ativo } | Sort-Object { [string]$_.nome })
    if ($ativos.Count -eq 0) { Msg-Aviso 'Não há pacientes ativos. Cadastre um paciente primeiro.'; Wait-Enter; return }
    if ($maps.Profissionais.Count -eq 0) { Msg-Aviso 'Não há profissionais. Cadastre um profissional primeiro.'; Wait-Enter; return }

    Write-Host '  Pacientes ativos:' -ForegroundColor Cyan
    Show-Table -Rows $ativos -Columns (Get-PacienteColumns)
    Write-Host ''
    $idPac = $null
    while ($true) {
        $idPac = Read-Id 'ID do paciente'
        if (Test-Cancel $idPac) { return }
        $okPac = @($ativos | Where-Object { $_.id -eq $idPac }).Count -gt 0
        if ($okPac) { break }
        Msg-Erro 'Paciente não encontrado entre os ativos. Escolha um ID da tabela.'
    }

    Write-Host ''
    Write-Host '  Profissionais:' -ForegroundColor Cyan
    Show-Table -Rows @($maps.Profissionais | Sort-Object { [string]$_.nome }) -Columns (Get-ProfissionalColumns)
    Write-Host ''
    $idProf = $null
    while ($true) {
        $idProf = Read-Id 'ID do profissional'
        if (Test-Cancel $idProf) { return }
        $okProf = @($maps.Profissionais | Where-Object { $_.id -eq $idProf }).Count -gt 0
        if ($okProf) { break }
        Msg-Erro 'Profissional não encontrado. Escolha um ID da tabela.'
    }

    Write-Host ''
    $txt = Read-Input -Label 'Data e hora' -Required -Validator $ValDataHora -Hint 'Formato: dd/MM/aaaa HH:mm   (ex.: 10/11/2026 14:30)'
    if (Test-Cancel $txt) { return }
    $dt = [datetime]::ParseExact($txt, 'dd/MM/yyyy HH:mm', $script:Inv)

    Write-Host ''
    Show-Ficha @(
        @('Paciente', (Get-Name $maps.MapP $idPac)),
        @('Profissional', (Get-Name $maps.MapPr $idProf)),
        @('Data/Hora', $dt.ToString('dd/MM/yyyy HH:mm', $script:Inv))
    )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar agendamento')) { Msg-Aviso 'Agendamento cancelado.'; Wait-Enter; return }

    $body = @{
        pacienteId     = $idPac
        profissionalId = $idProf
        dataHora       = $dt.ToString("yyyy-MM-dd'T'HH:mm:ss", $script:Inv)
    }
    $r = Invoke-Api -Method POST -Path '/agendamentos' -Body $body
    Write-Host ''
    if ($r.Ok) { Msg-Ok ('Agendamento criado com sucesso! ID: ' + $r.Data.id) } else { Show-ApiError $r }
    Wait-Enter
}

function Show-Agendamentos {
    Show-Banner 'Agendamentos > Listar todos'
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }
    $ags = Get-List '/agendamentos'
    if ($null -eq $ags) { Wait-Enter; return }
    $rows = ConvertTo-AgendaRows $ags $maps
    Show-Table -Rows $rows -Columns (Get-AgendaColumns) -EmptyMessage 'Nenhum agendamento cadastrado.'
    Wait-Enter
}

function Show-AgendaProfissional {
    Show-Banner 'Agendamentos > Agenda de um profissional'
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }
    if ($maps.Profissionais.Count -eq 0) { Msg-Aviso 'Não há profissionais cadastrados.'; Wait-Enter; return }
    Show-Table -Rows @($maps.Profissionais | Sort-Object { [string]$_.nome }) -Columns (Get-ProfissionalColumns)
    Write-Host ''
    $id = Read-Id 'ID do profissional'
    if (Test-Cancel $id) { return }
    if (@($maps.Profissionais | Where-Object { $_.id -eq $id }).Count -eq 0) {
        Msg-Erro 'Profissional não encontrado.'; Wait-Enter; return
    }
    Write-Host ''
    $ags = Get-List ('/agendamentos/profissional/' + $id)
    if ($null -eq $ags) { Wait-Enter; return }
    Write-Host ('  Agenda de ' + (Get-Name $maps.MapPr $id)) -ForegroundColor Cyan
    $rows = ConvertTo-AgendaRows $ags $maps
    Show-Table -Rows $rows -Columns (Get-AgendaColumns) -EmptyMessage 'Este profissional não possui agendamentos.'
    Wait-Enter
}

function Cancel-Agendamento {
    Show-Banner 'Agendamentos > Cancelar'
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }
    $ags = Get-List '/agendamentos'
    if ($null -eq $ags) { Wait-Enter; return }
    $abertos = @($ags | Where-Object { $_.situacao -eq 'AGENDADO' })
    if ($abertos.Count -eq 0) { Msg-Aviso 'Não há agendamentos ativos para cancelar.'; Wait-Enter; return }
    Show-Table -Rows (ConvertTo-AgendaRows $abertos $maps) -Columns (Get-AgendaColumns)
    Write-Host ''
    $id = Read-Id 'ID do agendamento'
    if (Test-Cancel $id) { return }
    $alvo = @($ags | Where-Object { $_.id -eq $id })
    if ($alvo.Count -eq 0) { Msg-Erro 'Agendamento não encontrado.'; Wait-Enter; return }
    if ($alvo[0].situacao -eq 'CANCELADO') { Msg-Aviso 'Este agendamento já está cancelado.'; Wait-Enter; return }
    Write-Host ''
    Show-Ficha @(
        @('ID', $alvo[0].id),
        @('Paciente', (Get-Name $maps.MapP $alvo[0].pacienteId)),
        @('Profissional', (Get-Name $maps.MapPr $alvo[0].profissionalId)),
        @('Data/Hora', (Format-Date $alvo[0].dataHora))
    )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar cancelamento')) { Msg-Aviso 'Operação cancelada.'; Wait-Enter; return }
    $r = Invoke-Api -Method PUT -Path ('/agendamentos/' + $id + '/cancelar')
    Write-Host ''
    if ($r.Ok) { Msg-Ok 'Agendamento cancelado com sucesso!' } else { Show-ApiError $r }
    Wait-Enter
}

function Show-MenuAgendamentos {
    while ($true) {
        Show-Banner 'Menu principal > Agendamentos'
        Show-MenuItems @(
            @('1', 'Novo agendamento'),
            @('2', 'Listar todos os agendamentos'),
            @('3', 'Agenda de um profissional'),
            @('4', 'Cancelar agendamento'),
            @('0', 'Voltar')
        )
        $c = Read-Choice @('0','1','2','3','4')
        switch ($c) {
            '1' { Invoke-Safe { New-Agendamento } }
            '2' { Invoke-Safe { Show-Agendamentos } }
            '3' { Invoke-Safe { Show-AgendaProfissional } }
            '4' { Invoke-Safe { Cancel-Agendamento } }
            '0' { return }
        }
    }
}

# ============================================================
#  ATENDIMENTOS / TRATAMENTOS
# ============================================================
function New-Atendimento {
    Show-Banner 'Atendimentos > Registrar atendimento'
    Write-Host '  Digite "cancelar" em qualquer campo para voltar.' -ForegroundColor DarkGray
    Write-Host ''
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }
    $ativos = @($maps.Pacientes | Where-Object { $_.ativo } | Sort-Object { [string]$_.nome })
    if ($ativos.Count -eq 0) { Msg-Aviso 'Não há pacientes ativos.'; Wait-Enter; return }
    if ($maps.Profissionais.Count -eq 0) { Msg-Aviso 'Não há profissionais cadastrados.'; Wait-Enter; return }

    Write-Host '  Pacientes ativos:' -ForegroundColor Cyan
    Show-Table -Rows $ativos -Columns (Get-PacienteColumns)
    Write-Host ''
    $idPac = $null
    while ($true) {
        $idPac = Read-Id 'ID do paciente'
        if (Test-Cancel $idPac) { return }
        if (@($ativos | Where-Object { $_.id -eq $idPac }).Count -gt 0) { break }
        Msg-Erro 'Paciente não encontrado entre os ativos.'
    }

    Write-Host ''
    Write-Host '  Profissionais:' -ForegroundColor Cyan
    Show-Table -Rows @($maps.Profissionais | Sort-Object { [string]$_.nome }) -Columns (Get-ProfissionalColumns)
    Write-Host ''
    $idProf = $null
    while ($true) {
        $idProf = Read-Id 'ID do profissional'
        if (Test-Cancel $idProf) { return }
        if (@($maps.Profissionais | Where-Object { $_.id -eq $idProf }).Count -gt 0) { break }
        Msg-Erro 'Profissional não encontrado.'
    }

    # agendamento opcional
    $idAg = $null
    $ags = Get-List '/agendamentos'
    if ($null -ne $ags) {
        $doPac = @($ags | Where-Object { $_.pacienteId -eq $idPac -and $_.situacao -eq 'AGENDADO' })
        if ($doPac.Count -gt 0) {
            Write-Host ''
            Write-Host '  Agendamentos ativos deste paciente (opcional):' -ForegroundColor Cyan
            Show-Table -Rows (ConvertTo-AgendaRows $doPac $maps) -Columns (Get-AgendaColumns)
            while ($true) {
                $t = Read-Input -Label 'ID do agendamento (ENTER para não vincular)' -Validator { param($v) if ($v -notmatch '^\d{1,12}$') { return 'Digite apenas números.' } }
                if (Test-Cancel $t) { return }
                if ($t -eq '') { break }
                if (@($doPac | Where-Object { $_.id -eq [long]$t }).Count -gt 0) { $idAg = [long]$t; break }
                Msg-Erro 'Escolha um dos IDs listados acima.'
            }
        }
    }

    Write-Host ''
    $desc = Read-Input -Label 'Descrição do tratamento/atendimento' -Required -Validator $ValDesc -Hint 'Até 255 caracteres. Ex.: Limpeza e aplicação de flúor.'
    if (Test-Cancel $desc) { return }

    $agTxt = 'Sem vínculo'
    if ($null -ne $idAg) { $agTxt = [string]$idAg }
    Write-Host ''
    Show-Ficha @(
        @('Paciente', (Get-Name $maps.MapP $idPac)),
        @('Profissional', (Get-Name $maps.MapPr $idProf)),
        @('Agendamento', $agTxt),
        @('Descrição', $desc)
    )
    Write-Host ''
    if (-not (Read-Confirm 'Confirmar registro')) { Msg-Aviso 'Registro cancelado.'; Wait-Enter; return }

    $r = Invoke-Api -Method POST -Path '/atendimentos' -Body @{ pacienteId = $idPac; profissionalId = $idProf; agendamentoId = $idAg; descricao = $desc }
    Write-Host ''
    if ($r.Ok) { Msg-Ok ('Atendimento registrado com sucesso! ID: ' + $r.Data.id) } else { Show-ApiError $r }
    Wait-Enter
}

function Show-HistoricoPaciente {
    Show-Banner 'Atendimentos > Histórico do paciente'
    $maps = Get-Maps
    if ($null -eq $maps) { Wait-Enter; return }
    Show-Table -Rows @($maps.Pacientes | Sort-Object { [string]$_.nome }) -Columns (Get-PacienteColumns) -EmptyMessage 'Nenhum paciente cadastrado.'
    Write-Host ''
    $id = Read-Id 'ID do paciente'
    if (Test-Cancel $id) { return }
    if (@($maps.Pacientes | Where-Object { $_.id -eq $id }).Count -eq 0) { Msg-Erro 'Paciente não encontrado.'; Wait-Enter; return }

    Write-Host ''
    $lista = Get-List ('/atendimentos/paciente/' + $id)
    if ($null -eq $lista) { Wait-Enter; return }
    Write-Host ('  Histórico de ' + (Get-Name $maps.MapP $id)) -ForegroundColor Cyan
    $rows = @()
    foreach ($a in @($lista | Sort-Object { Convert-ApiDate $_.data })) {
        $ag = '-'; if ($null -ne $a.agendamentoId) { $ag = [string]$a.agendamentoId }
        $rows += [pscustomobject]@{
            Id = $a.id; Data = (Format-Date $a.data); Prof = (Get-Name $maps.MapPr $a.profissionalId)
            Ag = $ag; Desc = [string]$a.descricao
        }
    }
    $cols = @(
        @{ H = 'ID';           W = 5;  A = 'R'; E = { param($r) $r.Id } },
        @{ H = 'Data/Hora';    W = 16; E = { param($r) $r.Data } },
        @{ H = 'Profissional'; W = 22; E = { param($r) $r.Prof } },
        @{ H = 'Agend.';       W = 7;  A = 'R'; E = { param($r) $r.Ag } },
        @{ H = 'Descrição';    W = 40; E = { param($r) $r.Desc } }
    )
    Show-Table -Rows $rows -Columns $cols -EmptyMessage 'Este paciente ainda não possui atendimentos registrados.'
    if ($rows.Count -gt 0) {
        Write-Host ''
        $t = Read-Input -Label 'ID de um atendimento para ver a descrição completa (ENTER para voltar)' -Validator { param($v) if ($v -notmatch '^\d{1,12}$') { return 'Digite apenas números.' } }
        if (-not (Test-Cancel $t) -and $t -ne '') {
            $sel = @($rows | Where-Object { [string]$_.Id -eq $t })
            Write-Host ''
            if ($sel.Count -gt 0) { Write-Host ('  ' + $sel[0].Desc) -ForegroundColor White } else { Msg-Erro 'ID não encontrado nesta lista.' }
        }
    }
    Wait-Enter
}

function Show-MenuAtendimentos {
    while ($true) {
        Show-Banner 'Menu principal > Atendimentos / Tratamentos'
        Show-MenuItems @(
            @('1', 'Registrar atendimento'),
            @('2', 'Histórico de um paciente'),
            @('0', 'Voltar')
        )
        $c = Read-Choice @('0','1','2')
        switch ($c) {
            '1' { Invoke-Safe { New-Atendimento } }
            '2' { Invoke-Safe { Show-HistoricoPaciente } }
            '0' { return }
        }
    }
}

# ============================================================
#  RESUMO / STATUS
# ============================================================
function Show-Status {
    Show-Banner 'Status da API e resumo'
    $pacs  = Get-List '/pacientes'
    $profs = Get-List '/profissionais'
    $ags   = Get-List '/agendamentos'
    if ($null -eq $pacs -or $null -eq $profs -or $null -eq $ags) { Wait-Enter; return }
    $ativos = @($pacs | Where-Object { $_.ativo }).Count
    $agOk   = @($ags | Where-Object { $_.situacao -eq 'AGENDADO' }).Count
    $agCan  = @($ags | Where-Object { $_.situacao -eq 'CANCELADO' }).Count
    Msg-Ok 'API online e respondendo.'
    Write-Host ''
    Show-Ficha @(
        @('Pacientes', ('{0} ({1} ativos, {2} inativos)' -f $pacs.Count, $ativos, ($pacs.Count - $ativos))),
        @('Profissionais', [string]$profs.Count),
        @('Agendamentos', ('{0} ({1} ativos, {2} cancelados)' -f $ags.Count, $agOk, $agCan))
    )
    Wait-Enter
}

# ============================================================
#  MENU PRINCIPAL
# ============================================================
function Start-SmartDental {
    if (-not (Test-ApiStartup)) {
        Write-Host ''
        Msg-Erro 'Não foi possível conectar à API. Encerrando.'
        return
    }
    while ($true) {
        Show-Banner 'Menu principal'
        Show-MenuItems @(
            @('1', 'Pacientes'),
            @('2', 'Profissionais'),
            @('3', 'Agendamentos'),
            @('4', 'Atendimentos / Tratamentos'),
            @('5', 'Status da API e resumo'),
            @('0', 'Sair')
        )
        $c = Read-Choice @('0','1','2','3','4','5')
        switch ($c) {
            '1' { Invoke-Safe { Show-MenuPacientes } }
            '2' { Invoke-Safe { Show-MenuProfissionais } }
            '3' { Invoke-Safe { Show-MenuAgendamentos } }
            '4' { Invoke-Safe { Show-MenuAtendimentos } }
            '5' { Invoke-Safe { Show-Status } }
            '0' {
                Show-Banner 'Até logo!'
                Msg-Ok 'Interface encerrada. Até a próxima!'
                return
            }
        }
    }
}

Start-SmartDental
