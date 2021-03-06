function [beta,beta0,conv] = elasticlin(X,Y,nu,lambda,options,beta,beta0)

% ELASTICLIN  Elastic net implementation using coordinate descent,
%             particularly suited for sparse high-dimensional models

% X: ninput x nsamples input data
% Y: 1 x nsamples output data
% nu: ninput x 1 weights for L1 penalty
% lambda: ninput x ninput matrix for ridge penalty
% options: struct with fields
%   offset: 1 if offset is learned as well [1]
%   maxiter: maximum number of iterations [10000]
%   tol: tolerance (mean absolute difference) [1e-6]
% beta: initial beta
% beta0: initial offset
%
% beta: ninput x 1 vector
% beta0: offset ([] if not applicable)
% conv: convergence

% Parsing inputs

  if nargin < 5,
    options = make_options;
  else
    options = make_options(options);
  end
  
  [ninput,nsamples] = size(X);
  
  if nargin < 4,
    lambda = 1;
  end
  
  if isscalar(lambda),
    lambda = lambda*ones(ninput,1);
  end
  
  if any(size(lambda) == 1),
    lambda = diag(lambda);
  end
  
  if nargin < 3,
    nu = 1;
  end
  
  if isscalar(nu),
    nu = nu*ones(ninput,1);
  end
  
  % Incorporating bias
  
  nvar = ninput;
  if options.offset,
    X = [X;ones(1,nsamples)];    % expand data with 1
    nvar = nvar+1;
    lambda(nvar,nvar) = 0;
    nu = [nu;0];                 % expand nu with 0 (no regularization)
  end
  
  % Initialization
    
  if nargin < 7,
    if options.offset,
      beta0 = 0;
    else
      beta0 = [];
    end
  end
  if nargin < 6,
    beta = zeros(ninput,1);
  end
  beta = [beta;beta0];
  
  % numerator of 10
  T = X*Y'/nsamples;   % nvar x 1  
  Q = zeros(nvar,nvar);
  qcomputed = zeros(nvar,1);
  activeset = (beta ~= 0);
  qcomputed(activeset) = 1;
  Q(:,activeset) = X*X(activeset,:)'/nsamples + lambda(:,activeset);   % precompute Q for nonzero beta
  Q(diag(activeset)) = 0;
  V = T-Q*beta;
  
  % denominator of Eq. 10 for nonstandardized variables
  U = diag(lambda) + mean(X.^2,2); 

  % Start iterations
  
  betaold = beta;
  iter = 0;
  activeset = true(1,nvar);
  conv = zeros(options.maxiter,1);
  while true
    
    iter = iter+1;
    
    % one full pass with all variables and then only with active set
    activeset = coorddescent(activeset);

    % fprintf('iteration %d of %d: %g\n',iter,options.maxiter,sum(abs(beta-betaold)));
    conv(iter) = sum(abs(beta-betaold));

    if iter==options.maxiter, break; end
    
    if sum(abs(beta-betaold)) < options.tol
      
      % again one full pass with all variables
      oldset = activeset;
      activeset = coorddescent(true(1,nvar));
      
      % if the active sets are the same we are done; otherwise continue
      if all(oldset==activeset) 
        break; 
      end
      
    end
    
    betaold = beta;
  end
  
  if iter == options.maxiter,
    fprintf('   be careful: maximum number of iterations reached\n');
  end
  
  % Parsing output
  
  if nargout > 1,
    if options.offset,
      beta0 = beta(end);
      beta = beta(1:ninput);
    else
      beta0 = [];
    end
  end
  
  function newset = coorddescent(activeset)
    
    beta(activeset) = 0;
    
    newset = false(1,nvar);
    for i=fliplr(find(activeset)) % run over weights and start with offset, if applicable
      
      if abs(V(i)) > nu(i) % active
        if V(i) > 0,
          beta(i) = (V(i) - nu(i))/U(i);
        else
          beta(i) = (V(i) + nu(i))/U(i);
        end
        newset(i) = 1;
      end
      
      if beta(i) ~= betaold(i)
        if ~qcomputed(i),    % compute Q when needed
          Q(:,i) = X*X(i,:)'/nsamples + lambda(:,i);
          Q(i,i) = 0;
          qcomputed(i) = 1;
        end
        V = V - Q(:,i)*(beta(i) - betaold(i));
      end
      
    end
    
  end

end

%%%%%%%%%%%%%%%%%%%%%%%    

function options = make_options(options)

  if nargin < 1,
    options = struct;
  end
  
  fnames = {'offset','maxiter','tol'};
  defaults = {1,1e4,1e-3};
  
  for i=1:length(fnames),
    if ~isfield(options,fnames{i}),
      options = setfield(options,fnames{i},defaults{i});
    end
  end

end