function [ res ] = solve_triangles_and_point0(gl, test, phi, lambda, etaTT, epsilon, n, chiDEF, chord_su_b, sigma, tmax_su_c )
    
    mdot_f = @(rho, b_su_Dm, n, phi, u, epsilon) pi * rho * b_su_Dm * 60^2 / pi^2 / n^2 * phi * u^3 * epsilon;
    
    u_f = @(mdot, rho, b_su_Dm, n, phi, epsilon) (mdot / (pi * rho * b_su_Dm * 60^2 / pi^2 / n^2 * phi * epsilon)) ^ (1/3);
    
    beta_f = @(lambda, u, eta, cp, TT0, k) (1-lambda * u^2 / (eta * cp * TT0)) ^(-1 / k);
    
    b_f = @(mdot, rho, Dm, n, vA, epsilon) mdot / (rho * Dm * pi * vA * epsilon);
    
    P0 = [];
    %first guess
    P0.p = gl.pT0;%1.468550111208940e+02;%gl.pT0;
    P0.T = gl.TT0;%9.687804143931812e+02;%gl.TT0;
    P0.k = gl.k0;
    P0.cp = gl.cp0;
    P0.rho = gl.rho0T;
    
    err_out = inf;
    %toll = 1e-6;
    old_out = P0.p;
    ii = 0;
    iii = 0;
    
    %% before to go into velocity triangle
    % I want to check how much partializzazion I have to perform
    %if test.b_from_Dm
    %clc
    % 0.04 is needed to have 0.025 in real result only when iterate
    b_su_DmMIN = 0.042;
    phiMIN = phi;%smith92_X(kk);%0.39;%0.4;
    lambdaMAX = lambda;%smith92_Y(kk);% 1.26;
    
    res.phi = phiMIN;
    res.lambda = lambdaMAX;
    % first guess
    res.etaTT = etaTT;
    
    %etaTT = 0.92;
    %epsilon = 1;
    %n = 9000;
    
    
    while err_out > gl.toll% && ii == 0 % fake iteration, make just one iteration
        
        %chiDEF = 0.75;
        deltaVaSQ = 0;
        deltaV02SQ = 0;
        
        rho0 = XSteam('rho_pT', P0.p, P0.T - 273.15);
        %etaTT = result.etaTT;
        %cp0 = XSteam('Cp_pT', P0.p, P0.T - 273.15);
        
        %         disp('-------------------------------------------------')
        %         disp(['------------ iteration number = ', num2str(ii+1),' ---------------'])
        %         disp('-------------------------------------------------')
        %         disp('Imposing mass flow')
        %         disp('b/Dm = 0.025 (min allowed)')
        %         disp(['lambda = deltaVT / u = ', num2str(lambdaMAX)])
        %         disp(['phi = vA / u = ', num2str(phiMIN)])
        %         disp(['partializzation epsilon = ', num2str(epsilon)])
        %         disp(['turbine rotational speed n = ', num2str(n), 'rpm'])
        
        u = u_f(gl.mdot, rho0, b_su_DmMIN, n, phiMIN, epsilon);
        vA = phiMIN * u;
        % lis = hT0 - hT2IS;
        % l = lis * etaTT
        % l = hT0 - hT2
        
        
        hT0 = XSteam('h_pt', gl.pT0, gl.TT0 - 273.15) * 1000;
        s0 = XSteam('s_pt', gl.pT0, gl.TT0 - 273.15);
        %single stage work
        l = lambdaMAX * u^2;
        hT2 = hT0 - abs(l);
        lIS = l / res.etaTT;
        hT2IS = hT0 - abs(lIS);
        pT2 = XSteam('p_hs', hT2IS / 1000, s0);
        beta = gl.pT0 / pT2;
        
        % to have total work for the entire betaTT
        hTend = hT0 - res.etaTT * (hT0 - XSteam('h_ps', gl.pT0 / gl.betaTT, s0) * 1000);
        
        
        %beta = beta_f(lambdaMAX, u, etaTT, P0.cp, gl.TT0, P0.k);
        %lIS = P0.cp * gl.TT0 * (beta ^ - P0.k - 1);
        %l = lIS * etaTT;
        Dm = 60 * u / pi / n;
        b = b_f(gl.mdot, rho0, Dm, n, vA, epsilon);
        b_su_Dm = b / Dm;
        %nStages = log(gl.betaTT) / log(beta);
        nStages = (hT0 - hTend) / l;
        
        %         print(u);
        %         print(vA);
        %         print(beta);
        %         print(lIS);
        %         print(l);
        %         print(Dm);
        %         print(b);
        %         print(b_su_Dm);
        %         print(nStages);
        
        res.n = n;
        res.uold = u;
        res.nstages = nStages;
        nStages = ceil(nStages);
        %print(nStages);
        
        %disp('-------------------------------------------------')
        %disp('with the rounded number of stages we recalculate everything')
        %beta = gl.betaTT ^(1 / nStages);
        l = (hT0 - hTend) / nStages;
        %lIS = P0.cp * gl.TT0 * (beta^-P0.k - 1);
        %lIS = P0.cp * gl.TT0 * (beta^-0.2 - 1);
        %l = lIS * etaTT;
        u = sqrt(abs(l) / lambdaMAX);
        vA = phiMIN * u;
        Dm = 60 * u / pi / n;
        b = b_f(gl.mdot, rho0, Dm, n, vA, epsilon);
        b_su_Dm = b / Dm;
        deltaVT = l / u;
        mdot = mdot_f(rho0, b_su_Dm, n, phiMIN, u, epsilon);
        res.mdot = mdot;
        
        
        %print(beta);
        %         print(lIS);
        %         print(l);
        %         print(u);
        %         print(vA);
        %         print(Dm);
        %         print(b);
        %         print(b_su_Dm);
        %         print(deltaVT)
        %         print(mdot);
        %end
        
        %% optimal velocity triangle
        
        if test.optimal_velocity_triangle
            alpha1_array = linspace(0.5, 1.5, 1000);
            res_alpha1 = zeros(size(alpha1_array));
            j = 1;
            for alpha1 = alpha1_array
                temp = velocity_triangle( u, vA, deltaVT, alpha1);
                res_alpha1(j) = temp.wvmax;
                j = j+1;
            end
            figure
            plot(alpha1_array, res_alpha1);
            grid on
        end
        
        % since we want a velocity triangle that minimizes the maximum velocity
        % we find the optimal condition when v1 is equal to w2 so that none of the
        % two is bigger than the other
        
        sumVt_f = @(chi, u, deltaVt, deltaVaSQ, deltaV02SQ)  2 *  u * (-chi + 1) - chi * (deltaV02SQ - deltaVaSQ) / deltaVt;
        
        
        if test.optimal_velocity_triangle
            opt_alpha1_f = @(alpha1) vA^2 + (vA * tan(alpha1) - abs(deltaVT) - u).^2 - vA^2 ./ (cos(alpha1).^2);
            alpha1_array = linspace(0.5, 1.3, 1000);
            figure
            plot(alpha1_array, opt_alpha1_f(alpha1_array));
            grid on
        end
        
        %alpha1 = secants(opt_alpha1_f, 0.8, 1.2);
        sumVt = sumVt_f(chiDEF, u, deltaVT, deltaVaSQ, deltaV02SQ);
        v1t = 0.5 * (sumVt + deltaVT);
        alpha1 = atan(v1t / vA);
        %alpha1_deg = rad2deg(alpha1);
        
        %print(alpha1)
        %print(alpha1_deg)
        
        triangle = velocity_triangle(u, vA, deltaVT, alpha1);
        %plot_velocity_triangle(triangle);
        
        chi_tr = (triangle.w2^2 - triangle.w1^2) / 2 / abs(l);
        %print(chi_tr)
        
        % some thermodynamic
        % Choosing repeated stage approach v0 = triangle.v2;
        
        %%
        % since this is the first stage we have an axial inlet
        P0 = pressure_temperature_from_totalREAL(gl, gl.pT0, gl.TT0, vA);
        P0.b = b_f(gl.mdot, P0.rho, Dm, n, vA, epsilon);
        P0.c = P0.b * chord_su_b;
        
        iterating = true;
        
        res.points = [P0];
        res.YTotStator = zeros(1, nStages);
        res.YTotRotor = zeros(1, nStages);
        chi_h = zeros(1, nStages);
        etas = zeros(1, nStages);
        betas = zeros(1, nStages);
        betasTT = zeros(1, nStages);
        
        %% TEST ITERATING CONSIDERING BLADE HEIGHT
        
        for nn = 1:nStages
            
            err = inf;
            b = P0.b * 0.95;% first guess
            oldb = b;
            %first guess
            P1.chord_su_b = chord_su_b;
            
            while err > gl.toll
                if nn == 1
                    vMeanStat = 0.5 * (vA + triangle.v1);
                    res.YTotStator(nn) = AinleyMathiesonLosses(test, iterating, 0, triangle.alpha1_deg, sigma, tmax_su_c, P0.rho, P0.mu, P1.chord_su_b*b, vMeanStat, 0, b);
                    
                    P1 = solve_statorREAL(gl, iterating, P0, triangle,  res.YTotStator(nn), beta);
                else
                    P0 = P2;
                    % v2 stands for v0 and alpha2 for alpha0
                    vMeanStat = 0.5 * (triangle.v2 + triangle.v1);
                    res.YTotStator(nn) = AinleyMathiesonLosses(test, iterating, triangle.alpha2_deg, triangle.alpha1_deg, sigma, tmax_su_c, P0.rho, P0.mu, P1.chord_su_b*b, vMeanStat, 0, b);
                    
                    P1 = solve_statorREAL(gl, iterating, P2, triangle, res.YTotStator(nn), beta);
                end
                
                % we scale from [0 1] to [rmin rmax]
                tempr = gl.XGauss * b + Dm / 2  - b / 2; % min + (max - min) * percentage
                temprho1 = zeros(gl.NGauss, 1);
                [tempVA1, tempVT1, ~, ~] = gl.velocity_evolution(triangle, Dm / 2, false, true, false, tempr);% only evaluate point 1
                tempV1sq = tempVA1.^2 + tempVT1.^2;
                
                for kk = 1:gl.NGauss
                    temprho1(kk) = solve_stator_streamline(gl, P0, tempV1sq(kk), res.YTotStator(nn));
                end
                
                % sum[mdot / (pi * dm * rho(r_i) * va(r_i)) * w_i]
                b = (gl.mdot / pi / Dm ./ temprho1 ./ tempVA1 / epsilon)' * gl.WGauss;
                
                P1.nBlades = ceil(pi * Dm / ( 1 / sigma * b * chord_su_b));
                P1.chord_su_b = pi * Dm / P1.nBlades / b * sigma;
                
                err = abs(oldb - b);
                
                oldb = b;
                %print(err)
                %print(b)
                iii = iii + 1;
            end
            P1.b = b;
            P1.c = P1.b * P1.chord_su_b;
            
            P1.span.r = tempr;
            P1.span.vA = tempVA1;
            P1.span.vT = tempVT1;
            P1.span.rho = temprho1;
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            vMeanRot = 0.5 * (triangle.w1 + triangle.w2);
            err = inf;
            b = P1.b * 0.95;% first guess
            oldb = b;
            %first guess
            P2 = P1;
            while err > gl.toll
                
                res.YTotRotor(nn) = AinleyMathiesonLosses(test, iterating, triangle.beta1_deg, triangle.beta2_deg,  sigma, tmax_su_c, mean([P1.rho, P2.rho]), mean([P1.mu, P2.mu]), chord_su_b*b, vMeanRot, b / 100, b);
                
                P2 = solve_rotorREAL(gl, iterating, P1, l, triangle, res.YTotRotor(nn), beta);
                
                b = gl.mdot / pi / Dm / P2.rho / vA;
                
                % we scale from [0 1] to [rmin rmax]
                tempr = gl.XGauss * b + Dm / 2  - b / 2; % min + (max - min) * percentage
                temprho2 = zeros(gl.NGauss, 1);
                [~, ~, tempVA2, tempVT2] = gl.velocity_evolution(triangle, Dm / 2, false, false, true, tempr); % only evaluate point 2
                tempW2sq = tempVA2.^2 + (tempVT2 - res.n * 2 * pi / 60 * tempr).^2;
                
                for kk = 1:gl.NGauss
                    temprho2(kk) = solve_rotor_streamline(gl, P1, tempW2sq(kk), res.YTotRotor(nn));
                end
                
                % sum[mdot / (pi * dm * rho(r_i) * va(r_i)) * w_i]
                b = (gl.mdot / pi / Dm ./ temprho2 ./ tempVA2 / epsilon)' * gl.WGauss;
                
                err = abs(oldb - b);
                
                oldb = b;
                iii = iii + 1;
            end
            P2.b = b;
            P2.c = P2.b * chord_su_b;
            P2.nBlades = ceil(pi * Dm / ( 1 / sigma * P2.b * chord_su_b));
            P2.chord_su_b = pi * Dm / P2.nBlades / P2.b * sigma;
            
            P2.span.r = tempr;
            P2.span.vA = tempVA2;
            P2.span.vT = tempVT2;
            P2.span.rho = temprho2;
            
            res.points = [res.points, [P1, P2]];
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            h2IS = XSteam('h_ps', P2.p, P0.s) * 1000;
            
            chi_h(nn) = (P1.h - P2.h) / (P0.h - P2.h);
            etas(nn) = (P0.h - P2.h) / (P0.h - h2IS);
            betas(nn) = P0.p / P2.p;
            betasTT(nn) = P0.pT / P2.pT;
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        if (2==3)
            for nn = 1:nStages
                
                err = inf;
                oldb = P0.b;
                %first guess
                b = gl.mdot / pi / Dm / P0.rho / vA;
                P1.chord_su_b = chord_su_b;
                
                %[b, P1, YTotStator] = stator_func(gl, test, triangle, first, P0, P1, Dm, vA, b, iterating);
                %stator_iterate_f = @(x) stator_func(gl, test, triangle, first, P0, x(2), Dm, vA, x(1), true);
                
                
                while err > gl.toll
                    if nn == 1
                        vMeanStat = 0.5 * (vA + triangle.v1);
                        res.YTotStator(nn) = AinleyMathiesonLosses(test, iterating, 0, triangle.alpha1_deg, sigma, tmax_su_c, P0.rho, P0.mu, P1.chord_su_b*b, vMeanStat, 0, b);
                        
                        P1 = solve_statorREAL(gl, iterating, P0, triangle,  res.YTotStator(nn), beta);
                    else
                        P0 = P2;
                        % v2 stands for v0 and alpha2 for alpha0
                        vMeanStat = 0.5 * (triangle.v2 + triangle.v1);
                        res.YTotStator(nn) = AinleyMathiesonLosses(test, iterating, triangle.alpha2_deg, triangle.alpha1_deg, sigma, tmax_su_c, P0.rho, P0.mu, P1.chord_su_b*b, vMeanStat, 0, b);
                        
                        P1 = solve_statorREAL(gl, iterating, P2, triangle, res.YTotStator(nn), beta);
                    end
                    
                    b = gl.mdot / pi / Dm / P1.rho / vA;
                    
                    P1.nBlades = ceil(pi * Dm / ( 1 / sigma * b * chord_su_b));
                    P1.chord_su_b = pi * Dm / P1.nBlades / b * sigma;
                    
                    err = abs(oldb - b);
                    
                    oldb = b;
                end
                P1.b = b;
                P1.c = P1.b * P1.chord_su_b;
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                vMeanRot = 0.5 * (triangle.w1 + triangle.w2);
                err = inf;
                oldb = P1.b;
                %first guess
                b = gl.mdot / pi / Dm / P1.rho / vA;
                P2 = P1;
                while err > gl.toll
                    
                    res.YTotRotor(nn) = AinleyMathiesonLosses(test, iterating, triangle.beta1_deg, triangle.beta2_deg,  sigma, tmax_su_c, mean([P1.rho, P2.rho]), mean([P1.mu, P2.mu]), chord_su_b*b, vMeanRot, b / 100, b);
                    
                    P2 = solve_rotorREAL(gl, iterating, P1, l, triangle, res.YTotRotor(nn), beta);
                    
                    b = gl.mdot / pi / Dm / P2.rho / vA;
                    
                    err = abs(oldb - b);
                    
                    oldb = b;
                end
                P2.b = b;
                P2.c = P2.b * chord_su_b;
                P2.nBlades = ceil(pi * Dm / ( 1 / sigma * P2.b * chord_su_b));
                P2.chord_su_b = pi * Dm / P2.nBlades / P2.b * sigma;
                
                res.points = [res.points, [P1, P2]];
                
                h2IS = XSteam('h_ps', P2.p, P0.s) * 1000;
                
                chi_h(nn) = (P1.h - P2.h) / (P0.h - P2.h);
                etas(nn) = (P0.h - P2.h) / (P0.h - h2IS);
                betas(nn) = P0.p / P2.p;
                betasTT(nn) = P0.pT / P2.pT;
            end
        end
        
        hTIS = XSteam('h_ps', res.points(end).pT, res.points(1).s) * 1000;
        res.etaTT =  (res.points(1).hT - res.points(end).hT) / (res.points(1).hT - hTIS);
        
        if  abs(abs(old_out-res.points(1).p) - err_out) < eps * 3 % sometimes the iteratio process does not converge
            err_out = 0;
        else
            err_out = abs(old_out-res.points(1).p);
        end
        old_out = res.points(1).p;
        %print(res.points(1).p)
        %print(err_out)
        
        ii = ii + 1;
        
        if(ii > gl.maxiter)
            % it is like a flag for error
            res.uold = [];
            %res.nstages = [];
            break;
        end
    end
    
    %% efficiency calculation
    
    %     %stator
    %     eta.statorSS = (P0.h - P1.h) / (P0.h - P1.hIS);
    %     eta.statorTT = (P0.hT - P1.hT) / (P0.hT - P1.hIS + 0.5*vA^2 - 0.5*triangle.v1^2);
    %
    %     %rotor
    %     eta.rotorSS = (P1.h - P2.h) / (P1.h - P2.hIS);
    %
    %     %stage
    %     hIS = P2.cp * P0.T * (P2.p / P0.p) ^ (0.5*P0.k + 0.5*P2.k);
    %
    %     eta.stageSS = (P0.h - P2.h) / (P0.h - hIS);
    %
    %     eta.stageTS = (P0.hT - P2.hT) / (P0.hT - hIS);
    %
    %     eta.stageTT = (P0.hT - P2.hT) / (P0.h - hIS + 0.5*vA^2 - 0.5*triangle.v2^2);
    
    % problem if we set it in a different way than this
    
    hIS = XSteam('h_ps', res.points(end).p, res.points(1).s) * 1000;
    hTIS = XSteam('h_ps', res.points(end).pT, res.points(1).s) * 1000;
    res.etaTT =  (res.points(1).hT - res.points(end).hT) / (res.points(1).hT - hTIS);
    res.etas = etas;
    res.betas = betas;
    res.betasTT = betasTT;
    res.eta =  (res.points(1).h - res.points(end).h) / (res.points(1).h - hIS);
    res.betaRes = res.points(1).p / res.points(end).p;
    res.betaResTT = res.points(1).pT / res.points(end).pT;
    
    
    %     for kk = 1:nStages
    %         chi_h(kk) = (res.points(2 * kk).h - res.points( 2 * kk + 1).h) / (res.points(2 * kk - 1).h - res.points( 2 * kk + 1).h);
    %     end
    %(P1.h - P2.h) / (P0.h - P2.h);
    
    %%
    
    if ~isempty(res.uold) && b_su_Dm > b_su_DmMIN && u < 600
        res.nstagesround = nStages;
        res.beta = beta;
        res.u = u;
        res.vA = vA;
        res.alpha1 = triangle.alpha1_deg;
        res.alpha2 = triangle.alpha2_deg;
        res.deltaBeta = triangle.deltaBetaDeg;
        res.b_su_Dm = b_su_Dm;
        res.Dm = Dm;
        res.b = b;
        res.lu1 = res.lambda  * res.u^2;
        res.lu2 = P0.cp * gl.TT0 * etaTT * (res.betaResTT ^ -P0.k - 1);
        %res.P0 = P0;
        %res.P1 = P1;
        %res.P2 = P2;
        res.chi_h = chi_h;
        res.chi_tr =chi_tr;
        res.triangle = triangle;
        res.ii = ii;
        res.iii = iii;
    else
        res.nstagesround = 0;
        res.beta = 0;
        res.u = 0;
        res.vA = 0;
        res.alpha1 = 0;
        res.alpha2 = 0;
        res.deltaBeta = 0;
        res.b_su_Dm = 0;
        res.Dm = 0;
        res.b =  0;
        res.lu1 = 0;
        res.lu2 = 0;
        %res.P0 = 0;
        %res.P1 = 0;
        %res.P2 = 0;
        res.chi_h = [];
        res.chi_tr = [];
        res.triangle = 0;
        res.ii = 0;
        res.iii = 0;
    end
    
end


function [b, P1, YTotStator] = stator_func(gl, test, triangle, first, P0, P1, Dm, vA, b, iterating)
    beta = 1; % unused
    
    v = inlineif(first, mean([triangle.v2, triangle.v1]), mean([vA, triangle.v1]));
    rho = mean([P0.rho, P1.rho]);
    mu = mean([P0.mu, P1.mu]);
    
    YTotStator(nn) = AinleyMathiesonLosses(test, iterating, inlineif(first, 0, triangle.alpha2_deg), triangle.alpha1_deg, P0.sigma, P0.tmax_su_c, rho, mu, P0.chord_su_b*b, v, 0, b);
    
    P1 = solve_statorREAL(gl, iterating, P0, triangle, YTotStator, beta);
    
    b = gl.mdot / pi / Dm / P2.rho / vA;
end
