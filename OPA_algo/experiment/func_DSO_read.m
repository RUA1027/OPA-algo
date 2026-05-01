function value = func_DSO_read(dsoObj)
%FUNC_DSO_READ Read one waveform from DSO and return mean voltage.

arguments
    dsoObj
end

try
    fprintf(dsoObj, ":WAVEFORM:PREAMBLE?");
    preambleLine = strtrim(fscanf(dsoObj));
    preamble = str2double(strsplit(preambleLine, ","));

    if numel(preamble) < 10 || any(~isfinite(preamble(8:10)))
        error("opa_exp:func_DSO_read:BadPreamble", ...
            "Invalid DSO preamble: %s", preambleLine);
    end

    yIncrement = preamble(8);
    yOrigin = preamble(9);
    yReference = preamble(10);

    fprintf(dsoObj, ":WAVEFORM:DATA?");
    raw = binblockread(dsoObj, "uint16");

    % Some instruments leave a terminator byte after BINBLOCK.
    try
        fread(dsoObj, 1);
    catch
    end

    if isempty(raw)
        error("opa_exp:func_DSO_read:EmptyData", "DSO returned empty waveform data.");
    end

    voltage = (double(raw) - yReference) .* yIncrement + yOrigin;
    value = mean(voltage);

    if ~isfinite(value)
        error("opa_exp:func_DSO_read:NonFinite", "DSO reading is non-finite.");
    end
catch ME
    error("opa_exp:func_DSO_read:ReadFailed", "DSO read failed: %s", ME.message);
end

end
