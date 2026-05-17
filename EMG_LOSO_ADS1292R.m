clear; clc; close all;
rng(42,'twister');

%% =========================================================
% CARGAR DATA
%% =========================================================

EXCEL_PATH = ...
"C:\Users\JOSE LUIS\Desktop\DOCUMENTOS PARA LO DEL PROYECTO DE INVESTIGACIÓN\extraccion de indices\MATLAB_TABLA_COMBINADA_EMG_ADS1292R.xlsx";

T = readtable(EXCEL_PATH,'VariableNamingRule','preserve');

disp("======================================")
disp("COLUMNAS DETECTADAS EN EL EXCEL:")
disp(T.Properties.VariableNames')
disp("======================================")

%% =========================================================
% CREAR CARPETA RESULTADOS
%% =========================================================

desktop_path = fullfile(getenv('USERPROFILE'),'Desktop');

main_out = fullfile(desktop_path,...
'LOSO_SANOS_VS_ESPASTICIDAD_FINAL_PCA');

if ~exist(main_out,'dir')
    mkdir(main_out);
end

%% =========================================================
% COLUMNAS
%% =========================================================

COL_FEATURES = [10 11 12 14 16];

COL_SUJETO = 3;

COL_COND = 18;

%% =========================================================
% MODELOS
%% =========================================================

modelos = {
    struct('nombre','LogReg','escala',true)
    struct('nombre','SVM-RBF','escala',true)
    struct('nombre','RandomForest','escala',false)
    struct('nombre','MLP','escala',true)
};

%% =========================================================
% FUNCIÓN LOSO
%% =========================================================

function ejecutar_LOSO_COMPLETO(...
    Tsub,...
    out_dir,...
    modelos,...
    COL_FEATURES,...
    COL_SUJETO)

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

%% =========================================================
% MATRICES
%% =========================================================

X = Tsub{:,COL_FEATURES};

y = categorical(string(Tsub.Label));

sujetos = categorical(string(Tsub{:,COL_SUJETO}));

sujetos_unicos = categories(sujetos);

clases_global = categories(y);

disp("======================================")
disp("CLASES DETECTADAS:")
disp(clases_global)
disp("======================================")

%% =========================================================
% FEATURE SELECTION
%% =========================================================

try

    idx = fscmrmr(X,y);

    idx = idx(1:min(5,length(idx)));

    X = X(:,idx);

catch
end

%% =========================================================
% VARIABLES
%% =========================================================

all_acc = [];
all_auc = [];

group_acc = {};
group_auc = {};

resumen_global = {};

%% =========================================================
% LOOP MODELOS
%% =========================================================

for m = 1:numel(modelos)

    nombre_modelo = modelos{m}.nombre;

    necesita_escala = modelos{m}.escala;

    metricas = [];

    auc_folds = [];

    y_true_all = categorical;
    y_pred_all = categorical;

    score_esp_all = [];
    score_sano_all = [];

    %% =====================================================
    % LOSO
    %% =====================================================

    for k = 1:numel(sujetos_unicos)

        te = sujetos == sujetos_unicos{k};

        tr = ~te;

        Xtr = X(tr,:);
        ytr = y(tr);

        Xte = X(te,:);
        yte = y(te);

        %% =================================================
        % VALIDAR CLASES
        %% =================================================

        if numel(unique(ytr)) < 2
            continue
        end

        %% =================================================
        % BALANCEO
        %% =================================================

        clases_train = categories(ytr);

        idx_bal = [];

        conteos = countcats(ytr);

        max_n = max(conteos);

        for c = 1:numel(clases_train)

            idx_c = find(ytr == clases_train{c});

            idx_rep = datasample(idx_c,...
                max_n,...
                'Replace',true);

            idx_bal = [idx_bal; idx_rep];

        end

        Xtr = Xtr(idx_bal,:);
        ytr = ytr(idx_bal);

        %% =================================================
        % ESCALADO
        %% =================================================

        if necesita_escala

            [Xtr,mu,sigma] = zscore(Xtr);

            sigma(sigma==0)=1;

            Xte = (Xte-mu)./sigma;

        end

        %% =================================================
        % PCA
        %% =================================================

        try

            [coeff,scoreTrain,~,~,explained,mu_pca] = pca(Xtr);

            var_acum = cumsum(explained);

            ncomp = find(var_acum>=95,1);

            Xtr = scoreTrain(:,1:ncomp);

            Xte = (Xte - mu_pca) * coeff(:,1:ncomp);

        catch
        end

        %% =================================================
        % ENTRENAMIENTO
        %% =================================================

        try

            switch nombre_modelo

                %% =========================================
                % LOGISTIC REGRESSION
                %% =========================================

                case 'LogReg'

                    t = templateLinear(...
                        'Learner','logistic',...
                        'Regularization','ridge');

                    mdl = fitcecoc(...
                        Xtr,...
                        ytr,...
                        'Learners',t,...
                        'Coding','onevsall');

                %% =========================================
                % SVM
                %% =========================================

                case 'SVM-RBF'

                    t = templateSVM(...
                        'KernelFunction','rbf',...
                        'KernelScale','auto',...
                        'BoxConstraint',2);

                    mdl = fitcecoc(...
                        Xtr,...
                        ytr,...
                        'Learners',t,...
                        'Coding','onevsall');

                %% =========================================
                % RANDOM FOREST
                %% =========================================

                case 'RandomForest'

                    mdl = fitcensemble(...
                        Xtr,...
                        ytr,...
                        'Method','Bag',...
                        'NumLearningCycles',400,...
                        'Learners','Tree');

                %% =========================================
                % MLP
                %% =========================================

                case 'MLP'

                    mdl = fitcnet(...
                        Xtr,...
                        ytr,...
                        'LayerSizes',[16 8],...
                        'Activations','relu',...
                        'IterationLimit',500,...
                        'Lambda',1e-3,...
                        'Standardize',false);

            end

            %% =============================================
            % PREDICCIÓN
            %% =============================================

            [ypred,score] = predict(mdl,Xte);

            ypred = categorical(ypred);

            if size(score,2)==2

                yprob = score;

            else

                yprob = normalize(score,2,'range');

            end

        catch ME

            disp(ME.message)
            continue

        end

        %% =================================================
        % MATRIZ CONFUSIÓN
        %% =================================================

        C = confusionmat(...
            yte,...
            ypred,...
            'Order',clases_global);

        acc = sum(diag(C))/sum(C,'all');

        %% =================================================
        % MÉTRICAS
        %% =================================================

        sensitivity = NaN;
        specificity = NaN;
        f1 = NaN;
        balanced_acc = NaN;

        if numel(clases_global)==2

            idx_sano = find(clases_global=="SANO");

            idx_esp = find(clases_global=="ESPASTICIDAD");

            TN = C(idx_sano,idx_sano);

            FP = C(idx_sano,idx_esp);

            FN = C(idx_esp,idx_sano);

            TP = C(idx_esp,idx_esp);

            sensitivity = TP/(TP+FN+eps);

            specificity = TN/(TN+FP+eps);

            precision = TP/(TP+FP+eps);

            recall = sensitivity;

            f1 = 2*(precision*recall)/(precision+recall+eps);

            balanced_acc = ...
                (sensitivity+specificity)/2;

            %% =============================================
            % SCORES
            %% =============================================

            score_esp = double(yprob(:,idx_esp));

            score_sano = double(yprob(:,idx_sano));

            score_esp_all = ...
                [score_esp_all; score_esp];

            score_sano_all = ...
                [score_sano_all; score_sano];

            %% =============================================
            % AUC
            %% =============================================

            y_bin = double(yte=="ESPASTICIDAD");

            if numel(unique(y_bin)) > 1

                [~,~,~,auc_fold] = ...
                    perfcurve(...
                    y_bin,...
                    score_esp,...
                    1);

                if auc_fold < 0.5
                    auc_fold = 1 - auc_fold;
                end

            else

                auc_fold = NaN;

            end

        else

            auc_fold = NaN;

        end

        %% =================================================
        % GUARDAR
        %% =================================================

        auc_folds = [auc_folds; auc_fold];

        metricas = [metricas;
            acc sensitivity specificity ...
            f1 balanced_acc];

        y_true_all = [y_true_all; yte];

        y_pred_all = [y_pred_all; ypred];

    end

    %% =====================================================
    % CONTINUAR
    %% =====================================================

    if isempty(metricas)
        continue
    end

    %% =====================================================
    % MATRIZ CONFUSIÓN
    %% =====================================================

    fig = figure('Visible','off');

    confusionchart(y_true_all,y_pred_all);

    title(['Confusion Matrix - ' nombre_modelo])

    saveas(fig,...
        fullfile(out_dir,...
        ['confusion_' nombre_modelo '.png']));

    close(fig)

    %% =====================================================
    % ROC
    %% =====================================================

    if numel(clases_global)==2

        fig = figure('Visible','off');

        hold on

        y_bin_esp = ...
            double(y_true_all=="ESPASTICIDAD");

        auc_esp = NaN;

        if numel(unique(y_bin_esp)) > 1 && ...
                ~isempty(score_esp_all)

            [fpr_esp,tpr_esp,~,auc_esp] = ...
                perfcurve(...
                y_bin_esp,...
                score_esp_all,...
                1);

            if auc_esp < 0.5

                [fpr_esp,tpr_esp,~,auc_esp] = ...
                    perfcurve(...
                    y_bin_esp,...
                    1-score_esp_all,...
                    1);

            end

            plot(...
                fpr_esp,...
                tpr_esp,...
                'b',...
                'LineWidth',3)

        end

        y_bin_sano = ...
            double(y_true_all=="SANO");

        auc_sano = NaN;

        if numel(unique(y_bin_sano)) > 1 && ...
                ~isempty(score_sano_all)

            [fpr_sano,tpr_sano,~,auc_sano] = ...
                perfcurve(...
                y_bin_sano,...
                score_sano_all,...
                1);

            if auc_sano < 0.5

                [fpr_sano,tpr_sano,~,auc_sano] = ...
                    perfcurve(...
                    y_bin_sano,...
                    1-score_sano_all,...
                    1);

            end

            plot(...
                fpr_sano,...
                tpr_sano,...
                'Color',[1 0.5 0],...
                'LineWidth',3)

        end

        plot([0 1],[0 1],...
            'k--','LineWidth',2)

        leg = {};

        if ~isnan(auc_esp)

            leg{end+1} = ...
                ['Espasticidad AUC=' ...
                num2str(auc_esp,3)];

        end

        if ~isnan(auc_sano)

            leg{end+1} = ...
                ['Sano AUC=' ...
                num2str(auc_sano,3)];

        end

        leg{end+1} = 'Azar';

        legend(leg,...
            'Location','southeast')

        xlabel('False Positive Rate')

        ylabel('True Positive Rate')

        title(['ROC - ' nombre_modelo])

        grid on

        xlim([0 1])

        ylim([0 1])

        set(gca,'FontSize',12)

        saveas(fig,...
            fullfile(out_dir,...
            ['roc_' nombre_modelo '.png']))

        close(fig)

    end

    %% =====================================================
    % BOXPLOTS
    %% =====================================================

    all_acc = [all_acc; metricas(:,1)];

    group_acc = [group_acc;
        repmat({nombre_modelo},...
        size(metricas,1),1)];

    all_auc = [all_auc; auc_folds];

    group_auc = [group_auc;
        repmat({nombre_modelo},...
        length(auc_folds),1)];

    %% =====================================================
    % RESUMEN
    %% =====================================================

    mean_acc = mean(metricas(:,1),'omitnan');

    std_acc = std(metricas(:,1),'omitnan');

    mean_auc = mean(auc_folds,'omitnan');

    std_auc = std(auc_folds,'omitnan');

    resumen_global = [resumen_global;
        {nombre_modelo,...
        mean_acc,...
        std_acc,...
        mean_auc,...
        std_auc}];

end

%% =========================================================
% BOXPLOT ACC
%% =========================================================

fig = figure;

boxplot(all_acc,group_acc)

ylabel('Accuracy')

title('LOSO Accuracy')

grid on

saveas(fig,...
    fullfile(out_dir,...
    'boxplot_acc.png'))

close(fig)

%% =========================================================
% BOXPLOT AUC
%% =========================================================

fig = figure;

boxplot(all_auc,group_auc)

ylabel('AUC')

title('LOSO AUC')

grid on

saveas(fig,...
    fullfile(out_dir,...
    'boxplot_auc.png'))

close(fig)

%% =========================================================
% TXT RESUMEN
%% =========================================================

fid = fopen(fullfile(out_dir,...
    'resumen_metricas.txt'),'w');

fprintf(fid,...
'Modelo\tMeanACC\tStdACC\tMeanAUC\tStdAUC\n');

for i = 1:size(resumen_global,1)

    fprintf(fid,...
    '%s\t%.4f\t%.4f\t%.4f\t%.4f\n',...
    resumen_global{i,1},...
    resumen_global{i,2},...
    resumen_global{i,3},...
    resumen_global{i,4},...
    resumen_global{i,5});

end

fclose(fid);

end

%% =========================================================
% DATASETS
%% =========================================================

condicion = string(T{:,COL_COND});

%% =========================================================
% REPOSO
%% =========================================================

T2 = T(condicion=="REPOSO",:);

T2 = rmmissing(T2);

T2.Label = string(T2.GRUPO);

ejecutar_LOSO_COMPLETO(...
    T2,...
    fullfile(main_out,...
    '02_REPOSO_Sano_vs_Espasticidad'),...
    modelos,...
    COL_FEATURES,...
    COL_SUJETO);

%% =========================================================
% CISP
%% =========================================================

T3 = T(condicion=="CISP",:);

T3 = rmmissing(T3);

T3.Label = string(T3.GRUPO);

ejecutar_LOSO_COMPLETO(...
    T3,...
    fullfile(main_out,...
    '03_CISP_Sano_vs_Espasticidad'),...
    modelos,...
    COL_FEATURES,...
    COL_SUJETO);

disp("======================================")
disp("LOSO COMPLETADO")
disp("======================================")
