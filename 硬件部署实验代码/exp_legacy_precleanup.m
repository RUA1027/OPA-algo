function exp_legacy_precleanup()
%EXP_LEGACY_PRECLEANUP Perform legacy-style hardware/session cleanup before a run.

try
    legacyInstrFindAll = str2func("instrfindall");
    staleHandles = legacyInstrFindAll();
    if ~isempty(staleHandles)
        delete(staleHandles);
    end
catch
end

end
