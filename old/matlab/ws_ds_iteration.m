tic
global m_P beta_TOT R Cp gamma p0 T0 ws Ds eta l graph v_M

graph = true;
ff = 1;

howell_init
balje_init

m_P = 65;%kg/s
beta_TOT = 13.5;
R = 287;%K/kgK
gamma = 1.4;
Cp = gamma/(gamma-1)*R;%K/kgK
p0 = 0.85*1e5;%pa
T0 = 268;%k
rho0 = p0/R/T0;

l = @(eta, T_in, beta) Cp*T_in/eta*(beta^((gamma-1)/gamma)-1);

%da balje
% ws_Ds_array_error = [];
% ws_Ds_error_index = 1;

% if exist('data\ws_ds_wrong.mat', 'file') == 2
%     load('data\ws_ds_wrong.mat')
%     ws_Ds_error_index = size(ws_Ds_array_error,1);
% end

% ws_array = linspace(2.3,2.5,100);
% Ds_array = linspace(1.9,2.2,100);

ws_array = linspace(1.5,4.3,250);
Ds_array = linspace(1.8,3.3,250);

ii = 0;
% p0_ = p0;
% m_P_ = m_P;

iter_res(1).ws = [];
iter_res(1).Ds = [];
iter_res(1).beta_TOT = [];
iter_res(1).eta_TOT = [];
iter_res(1).eta_TOT_in_out = [];
iter_res(1).N_TOT = [];
iter_res(1).beta_MEDIO = [];
iter_res(1).D = [];
iter_res(1).w = [];
iter_res(1).rpm = [];
iter_res(1).T_OUT = [];
iter_res(1).errorU = [];
iter_res(1).errorBalje = [];
iter_res(1).errorbsuD = [];

for ws = ws_array
    
    for Ds = Ds_array
        
%         if ~isempty(ws_Ds_array_error) && ismember([ws, Ds], ws_Ds_array_error, 'rows')
%             continue;
%         end
        
        ii = ii+1;
        iter_res(ii).ws = ws;
        iter_res(ii).Ds = Ds;
        
        eta = balje(ws,Ds);%da balje
        
        if isnan(eta)
            iter_res(ii).errorBalje = true;
            iter_res(ii).errorU = false;
            continue;
        end
        
        %% OTTIMIZZAZIONE BETA CON U MASSIMO POSSIBILE
        
        uu_opt = zeros(300,1); jj = 1;
        %beta_approx_array = linspace(1.19,1.21,500);
        beta_approx_array = linspace(1.1,1.4,300);
        
        for beta_approx = beta_approx_array;
            
            [ST,~,n_intermedio] = calcolo_stadi_beta_costante(beta_approx);
            
            uu_opt(jj) = ST(n_intermedio).U;
            jj = jj + 1;
            
        end
        
        %plot(beta_approx_array,uu_opt);
        
        beta_approx = beta_approx_array(find(uu_opt<500,1,'last'));
        
        if isempty(beta_approx) || max(uu_opt) < 500
            iter_res(ii).errorU = true;
            continue
        end
        
        iter_res(ii).errorU = false;
        
        %% CALCOLO STADI CON BETA OTTIMIZZATO
        
        [ST,N,n_intermedio] = calcolo_stadi_beta_costante(beta_approx);
        
        ST_stima_beta_cost = ST;
        
        jj = 1;
        v_m = zeros(500,1);
        alpha1_array = linspace(0.1,deg2rad(50),500);
        
        for alpha1 = alpha1_array
            
            beta2 = -alpha1;
            
            deltaBeta = howell(howell_POLY,beta2);
            %deltaBeta = deg2rad(deltaBeta);
            
    v_m(jj) = ST(n_intermedio).l/ST(n_intermedio).U/(abs(tan(abs(beta2)+deltaBeta))-tan(abs(beta2)));
            %v_m(jj) = ST(n_intermedio).l/ST(n_intermedio).U/(tan(beta2+deltaBeta)-tan(beta2));
            jj = jj +1;
        end
        
        v_M = max(v_m);%(end)
        
        beta2_deg = rad2deg(-alpha1_array(v_M == v_m));
        
        [deltabeta, beta1] = howell(howell_POLY, deg2rad(beta2_deg));
        
        deltabeta_deg = rad2deg(deltabeta);
        beta1_deg = rad2deg(beta1);
        
        ST0 = ST(1);
        ST0.l = ST(n_intermedio).l;
        ST0.U = ST(n_intermedio).U;
        ST0.D = ST(n_intermedio).D;
        ST0.w = ST(n_intermedio).w;
        
        ST = calcolo_stadi_l_costante_da_inizio(N+2,ST0);
        
        if isnan(ST(end).p_OUT) || max([ST.beta]) > 1.4
            iter_res(ii).errorBalje = true;
            continue
        end
        iter_res(ii).errorBalje = false;
        
        L_punto = sum([ST.deltaH_IS])*m_P;
        L_punto_entrante = length(ST)*ST(1).l*m_P;
        
        iter_res(ii).beta_TOT = ST(end).p_OUT/p0;
        iter_res(ii).eta_TOT = L_punto/L_punto_entrante;
        iter_res(ii).eta_TOT_in_out = l(1,T0,ST(end).p_OUT/p0)*m_P/L_punto_entrante;
        iter_res(ii).N_TOT = length(ST);
        iter_res(ii).beta_MEDIO = iter_res(ii).beta_TOT^(1/length(ST));
        iter_res(ii).T_OUT = ST(end).T_OUT;
        iter_res(ii).D = ST(end).D;
        iter_res(ii).w = ST(end).w;
        iter_res(ii).rpm = ST(end).rpm;
        iter_res(ii).bsuD_MIN = min([ST.bsuD]);
        iter_res(ii).bsuD_MAX = max([ST.bsuD]);
        
        disp([num2str(ii/length(ws_array)/length(Ds_array)*100), '% di completamento'])
    end
end

disp('Terminato')
toc

%% plot figure

% for iter_res_item = iter_res
%     if iter_res_item.errorU || iter_res_item.errorBalje
%         if isempty(ws_Ds_array_error) || ~ismember([ws, Ds], ws_Ds_array_error, 'rows')
%             ws_Ds_array_error(ws_Ds_error_index,:) = [iter_res_item.ws, iter_res_item.Ds];
%             ws_Ds_error_index = ws_Ds_error_index+1;
%         end
%     end
% end

%save('data\ws_ds_wrong.mat','ws_Ds_array_error')

iter_res_noempty = remove_empty_iter_res(iter_res);

Z_iter_res = zeros(length(ws_array),length(Ds_array));

for iter_res_item = iter_res
    
    %Z_iter_res(find(ws_array==iter_res_item.ws),find(Ds_array==iter_res_item.Ds)) = iter_res_item.beta_TOT;
    if ~isnan( iter_res_item.beta_TOT)
        Z_iter_res(find(ws_array==iter_res_item.ws),find(Ds_array==iter_res_item.Ds)) = iter_res_item.beta_MEDIO;
    else Z_iter_res(find(ws_array==iter_res_item.ws),find(Ds_array==iter_res_item.Ds)) =    1; %1
    end
    
end

%imagesc(([iter_res.ws]),([iter_res.Ds]),Z_iter_res);


imagesc(ws_array,Ds_array,Z_iter_res);

%% save data
name = ['data\data',num2str(ws_array(1)),'-',num2str(ws_array(end)),'_',num2str(Ds_array(1)),'-',num2str(Ds_array(end)),' ',num2str(length(ws_array)),'X',num2str(length(Ds_array))];

savefig([name,'.fig']);

save([name,'.mat'],'Ds_array','ws_array','iter_res','iter_res_noempty');

%% ottimo di beta medio
mask_opt = [iter_res_noempty.beta_MEDIO]==max([iter_res_noempty.beta_MEDIO]);
item_opt = iter_res_noempty(mask_opt);
item_opt = item_opt(1);
item_beta_medio_OPT  = iter_res_noempty(mask_opt);

disp('----------------------------------------------------')
disp(['Ottimo di beta medio:'])
disp(['ws = ', num2str(item_opt.ws)])
disp(['Ds = ', num2str(item_opt.Ds)])
disp(['w = ', num2str(item_opt.w)])
disp(['D = ', num2str(item_opt.D)])
disp(['rpm = ', num2str(item_opt.rpm)])
disp(['Beta medio = ', num2str(item_opt.beta_MEDIO)])
disp(['N con beta medio = ', num2str(log(beta_TOT)/log(item_opt.beta_MEDIO))])
disp(['Eta totale = ', num2str(item_opt.eta_TOT)])
disp(['Eta totale in out = ', num2str(item_opt.eta_TOT_in_out)])
disp(['T out = ', num2str(item_opt.T_OUT)])

%% ottimo di rendimento
mask_opt = [iter_res_noempty.eta_TOT]==max([iter_res_noempty.eta_TOT]);
item_opt = iter_res_noempty(mask_opt);
item_opt = item_opt(1);
item_eta_tot_OPT  = iter_res_noempty(mask_opt);

disp('----------------------------------------------------')
disp(['Ottimo di rendimento:'])
disp(['ws = ', num2str(item_opt.ws)])
disp(['Ds = ', num2str(item_opt.Ds)])
disp(['w = ', num2str(item_opt.w)])
disp(['D = ', num2str(item_opt.D)])
disp(['rpm = ', num2str(item_opt.rpm)])
disp(['Beta medio = ', num2str(item_opt.beta_MEDIO)])
disp(['N con beta medio = ', num2str(log(beta_TOT)/log(item_opt.beta_MEDIO))])
disp(['Eta totale = ', num2str(item_opt.eta_TOT)])
disp(['Eta totale in out = ', num2str(item_opt.eta_TOT_in_out)])
disp(['T out = ', num2str(item_opt.T_OUT)])

%% ottimo di rendimento in out
mask_opt = [iter_res_noempty.eta_TOT_in_out]==max([iter_res_noempty.eta_TOT_in_out]);
item_opt = iter_res_noempty(mask_opt);
item_opt = item_opt(1);
item_eta_tot_in_out_OPT  = iter_res_noempty(mask_opt);

disp('----------------------------------------------------')
disp(['Ottimo di rendimento in out:'])
disp(['ws = ', num2str(item_opt.ws)])
disp(['Ds = ', num2str(item_opt.Ds)])
disp(['w = ', num2str(item_opt.w)])
disp(['D = ', num2str(item_opt.D)])
disp(['rpm = ', num2str(item_opt.rpm)])
disp(['Beta medio = ', num2str(item_opt.beta_MEDIO)])
disp(['N con beta medio = ', num2str(log(beta_TOT)/log(item_opt.beta_MEDIO))])
disp(['Eta totale = ', num2str(item_opt.eta_TOT)])
disp(['Eta totale in out = ', num2str(item_opt.eta_TOT_in_out)])
disp(['T out = ', num2str(item_opt.T_OUT)])


