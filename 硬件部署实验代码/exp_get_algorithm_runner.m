function runner = exp_get_algorithm_runner(method)
%EXP_GET_ALGORITHM_RUNNER Resolve method string to experiment runner.

% 实验框架中，根据传入的算法名，快速找到并返回对应的执行函数
% 核心价值：统一算法名称格式、自动映射函数，屏蔽输入格式差异，简化实验代码调用

arguments
    method {mustBeTextScalar}
end

% 对输入方法名做统一归一化：
% - 先转大写，消除大小写差异；
% - 再去掉分隔符（如 "-"、空格），消除书写格式差异。
% 例如："mREV-GSS" -> "MREVGSS"。
token = iNormalizeMethodToken(method);

% 统一分发入口：返回对应算法运行器函数句柄。
% 后续由 exp_run_calibration 调用该句柄执行具体算法。
switch token
    case "MREVGSS"
        runner = @exp_run_mrevgss;
    case {"5PPS", "FIVEPPS"}
        runner = @exp_run_5pps;
    case "PFPD"
        runner = @exp_run_pfpd;
    case "CAIO"
        runner = @exp_run_caio;
    otherwise
        error("opa_exp:exp_get_algorithm_runner:UnsupportedMethod", "Unsupported method: %s", method);
end

end

    function token = iNormalizeMethodToken(method)
    % Uppercase first, then strip non-alphanumerics to keep tokens stable
    % for mixed-case inputs like "mREV-GSS".
    % 注意：该归一化函数是方法分发稳定性的关键，
    % 若后续新增方法名别名，建议先在此处评估归一化后冲突风险。
    token = regexprep(upper(string(method)), "[^A-Z0-9]", "");
    end
