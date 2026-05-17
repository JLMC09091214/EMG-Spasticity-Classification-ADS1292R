clear; clc; close all;
rng(42,'twister');

%% ================================
% CONFIGURACIÓN
%% ================================

EXCEL_PATH = "C:\Users\JOSE LUIS\Desktop\DOCUMENTOS PARA LO DEL PROYECTO DE INVESTIGACIÓN\extraccion de indices\MATLAB_TABLA_COMBINADA_EMG_ADS1292R.xlsx";

T = readtable(EXCEL_PATH);
desktop_path = fullfile(getenv('USERPROFILE'),'Desktop');

% Columnas según tu Excel
COL_GRUPO     = 2;     % GRUPO
COL_CONDICION = 18;    % REPOSO / CISP
COL_FEATURES  = 8:17;  % DASDV hasta ZC

feature_names = T.Properties.VariableNames(COL_FEATURES);

%% ================================
% MODELOS
%% ================================

modelos = { ...
    struct('nombre','LogReg','escala',true), ...
    struct('nombre','SVM_RBF','escala',true), ...
    struct('nombre','RandomForest','escala',false), ...
    struct('nombre','MLP','escala',true) ...
};

%% =============================================================
% FUNCIÓN GENERAL
%% =============================================================
function ejecutar_experimento(Tsub, nombre_carpeta, modelos, desktop_path, COL_FEATURES, feature_names)

    out_dir = fullfile(desktop_path,nombre_carpeta);
    if ~exist(out_dir,'dir'); mkdir(out_dir); end

    X = Tsub{:,COL_FEATURES};
    y = categorical(string(Tsub.Label));

    clases = categories(y);
    n_classes = numel(clases);

    cvp = cvpartition(y,'KFold',5,'Stratify',true);

    resultados_folds = containers.Map;

    %% ==========================
    % ENTRENAMIENTO
    %% ==========================
    for m = 1:numel(modelos)

        nombre_modelo = modelos{m}.nombre;
        necesita_escala = modelos{m}.escala;

        nombre_archivo = regexprep(nombre_modelo,'[^a-zA-Z0-9]','_');

        y_true_all = [];
        y_pred_all = [];
        y_score_all = [];

        metricas = zeros(cvp.NumTestSets,2);

        modelo_valido = true;

        for k = 1:cvp.NumTestSets

            tr = cvp.training(k);
            te = cvp.test(k);

            Xtr = X(tr,:); ytr = y(tr);
            Xte = X(te,:); yte = y(te);

            if necesita_escala
                [Xtr,mu,sigma] = zscore(Xtr);
                sigma(sigma==0)=1;
                Xte = (Xte-mu)./sigma;
            end

            switch nombre_modelo

                case 'LogReg'
                    mdl = fitcecoc(Xtr,ytr);

                case 'SVM_RBF'
                    t = templateSVM('KernelFunction','rbf');
                    mdl = fitcecoc(Xtr,ytr,'Learners',t);

                case 'RandomForest'
                    mdl = fitcensemble(Xtr,ytr,'Method','Bag','NumLearningCycles',400);

                case 'MLP'
                    try
                        mdl = fitcnet(Xtr,ytr,...
                            'LayerSizes',[32 16],...
                            'Activations','relu',...
                            'Standardize',false);
                    catch
                        warning('MLP no disponible. Se omite.');
                        modelo_valido = false;
                        break
                    end
            end

            [ypred,yprob] = predict(mdl,Xte);

            acc = mean(ypred==yte);

            auc = 0;
            for c = 1:n_classes
                [~,~,~,auc_c] = perfcurve(double(yte==clases{c}),yprob(:,c),1);
                auc = auc + auc_c;
            end
            auc = auc/n_classes;

            metricas(k,:) = [acc auc];

            y_true_all = [y_true_all; yte];
            y_pred_all = [y_pred_all; ypred];
            y_score_all = [y_score_all; yprob];
        end

        if ~modelo_valido
            continue
        end

        %% Guardar métricas
        df = array2table(metricas,'VariableNames',{'accuracy','auc'});
        writetable(df,fullfile(out_dir,['metrics_por_fold_' nombre_archivo '.csv']));
        resultados_folds(nombre_modelo) = df;

        %% Matriz de confusión
        fig = figure('Visible','off');
        C = confusionmat(y_true_all,y_pred_all,'Order',clases);
        confusionchart(C,clases,'ColumnSummary','column-normalized','RowSummary','row-normalized');
        saveas(fig,fullfile(out_dir,['confusion_' nombre_archivo '.png']));
        close(fig);

        %% ROC
        fig = figure('Visible','off'); hold on;
        for c = 1:n_classes
            [fpr,tpr,~,~] = perfcurve(double(y_true_all==clases{c}),y_score_all(:,c),1);
            plot(fpr,tpr,'LineWidth',1.5);
        end
        plot([0 1],[0 1],'k--');
        legend(clases,'Location','southeast');
        title(['ROC OvR - ' nombre_modelo]);
        grid on;
        saveas(fig,fullfile(out_dir,['roc_ovr_' nombre_archivo '.png']));
        close(fig);
    end

    %% ==========================
    % BOXPLOT MÉTRICAS
    %% ==========================
    nombres = keys(resultados_folds);

    if ~isempty(nombres)

        acc_data=[]; auc_data=[];
        for i=1:numel(nombres)
            df = resultados_folds(nombres{i});
            acc_data=[acc_data df.accuracy];
            auc_data=[auc_data df.auc];
        end

        fig=figure('Visible','off');
        boxplot(acc_data,'Labels',nombres);
        ylabel('Accuracy');
        saveas(fig,fullfile(out_dir,'boxplot_acc.png'));
        close(fig);

        fig=figure('Visible','off');
        boxplot(auc_data,'Labels',nombres);
        ylabel('AUC');
        saveas(fig,fullfile(out_dir,'boxplot_auc.png'));
        close(fig);
    end

    %% ==========================
    % BOXPLOTS DE CADA FEATURE
    %% ==========================
    for f = 1:length(feature_names)

        nombre_feat_arch = regexprep(feature_names{f},'[^a-zA-Z0-9]','_');

        fig = figure('Visible','off');
        boxchart(y, X(:,f));
        title(['Distribución ' feature_names{f}]);
        ylabel(feature_names{f});
        grid on;

        saveas(fig,fullfile(out_dir,['boxplot_' nombre_feat_arch '.png']));
        close(fig);
    end

end

%% =============================================================
% 1) 3 CLASES SOLO SANOS
%% =============================================================
T_sanos = T(strcmp(string(T{:,COL_GRUPO}),"SANO"),:);
T_sanos.Label = string(T_sanos{:,COL_CONDICION});
ejecutar_experimento(T_sanos,"01_Clases_Sanos_Completado",modelos,desktop_path,COL_FEATURES,feature_names);

%% =============================================================
% 2) REPOSO SANOS vs ESPASTICIDAD
%% =============================================================
idx_reposo = strcmp(string(T{:,COL_CONDICION}),"REPOSO");
T_reposo = T(idx_reposo,:);
T_reposo.Label = string(T_reposo{:,COL_GRUPO});
ejecutar_experimento(T_reposo,"02_Reposo_Sanos_vs_Espasticidad_Completado",modelos,desktop_path,COL_FEATURES,feature_names);

%% =============================================================
% 3) CISP SANOS vs ESPASTICIDAD
%% =============================================================
idx_cisp = strcmp(string(T{:,COL_CONDICION}),"CISP");
T_cisp = T(idx_cisp,:);
T_cisp.Label = string(T_cisp{:,COL_GRUPO});
ejecutar_experimento(T_cisp,"03_CISP_Sanos_vs_Espasticidad_Completado",modelos,desktop_path,COL_FEATURES,feature_names);

disp('==============================================')
disp('EXPERIMENTO COMPLETADO CORRECTAMENTE')