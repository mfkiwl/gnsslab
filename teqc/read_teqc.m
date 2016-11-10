function [mjd, prn, dat] = read_teqc(file)
% READ_TEQC reads the TEQC report file which contains azi, ele, sn1, sn2,
% mp1, mp2, ion, iod data. TEQC is the Toolkit for GNSS data pre-processing.
% More info see http://facility.unavco.org/software/teqc/teqc.html
%
% SYNTAX:
%   [mjd, prn, dat] = read_teqc(file);
%
% INPUT:
%   file - report file name generated by TEQC.
%
% OUTPUT:
%   mjd - epoch time in modified Julian date [n x 1]
%   prn - cell array of the satellite PRN numbers [1 x m]
%   dat - the output data [n x m]
%
% REFERENCE
%   TEQC: The Multi-Purpose Toolkit for GPS/GLONASS Data, L. H. Estey and C. M.
%   Meertens, GPS Solutions (pub. by John Wiley & Sons), Vol.3, No.1, pp. 42-49,
%   1999.
%
%   File format reference:
%   <http://ls.unavco.org/pipermail/teqc/2007/000566.html>
%   <http://ls.unavco.org/pipermail/teqc/2009/000827.html>
%   <http://postal.unavco.org/pipermail/teqc/2013/001594.html>
%
% See also PLOT_TEQC.

% validate the number of input arguments
narginchk(1, 1);

% read the whole file to a temporary cell array
[fid, message] = fopen(file, 'rt');
if fid == -1
    error ('Open file %s failed: %s.\n', file, message);
else
    buf = textscan(fid,'%s','delimiter','\n','whitespace','');
    buf = buf{1};
end
fclose(fid);

% tstart = tic;

% read the 1st line & check for UNAVCO file compatibility
switch upper(strtrim(buf{1}))
    case 'COMPACT' ,
        % ver = 1;
        buf = buf(3:end); % ignore the SVS line for ver 1.0
        [mjd, prn, dat] = read_compact2(buf);
    case 'COMPACT2',
        % ver = 2;
        buf = buf(2:end);
        [mjd, prn, dat] = read_compact2(buf);
    case 'COMPACT3',
        % ver = 3;
        buf = buf(2:end);
        [mjd, prn, dat] = read_compact3(buf);
    otherwise,
        error('%s is corrupt or is NOT a teqc report file', file);
end

end

function [mjd, prn, dat] = read_compact2(buf)

n = length(buf); % number of lines
dat = nan(n,99); % preallocate memory

% T_SAMP: interval
tint = sscanf(buf{1},'%*s%g');
% START_TIME_MJD: start mjd
mjd0 = sscanf(buf{2},'%*s%g');

% the following lines are sat and data
prnlist =[];
i = 2; % index of buf
m = 0; % epoch number

while (i < n) % loop through the buf
    i = i + 1;
    line = buf{i};                  % list of the SVs
    if ~ischar(line); break; end;   % if end of the file, stop reading file
    
    m = m + 1;
    c = textscan(line,'%s');    % read the number of sats and sv numbers
    c = c{1};
    nsat = str2double(c(1));
    
    if nsat == 0
        % if there are no sats, ignored
        continue;
    elseif nsat > 0
        % if there are sats
        prn = str2prn(c(2:end));
        [~, ~, ib] = intersect(prnlist, prn);
        
        ii = true(length(prn),1);
        ii(ib,1) = false;
        prnlist = [prnlist; prn(ii)]; %#ok<AGROW>
        
        [~, ia, ib] = intersect(prnlist, prn);
        
    elseif nsat ~= -1
        error('Invalid line %d:\n%s', i+1, line);       
    end
    
    % if there is a line of observation data
    i = i + 1;
    line = buf{i};                  % list of the SVs
    if ~ischar(line); break; end;   % if end of the file, stop reading file
    
    [obs, nobs] = sscanf(line,'%f');		% read the data
    % there are some bugs in teqc, so we need to use number of sats in the epoch
    % to define the data to be stored
    num = min(length(ib), nobs);
    dat(m,ia(1:num)) = obs(ib(1:num))';
end

fod = tint .* (0:m-1)'/86400;
mjd = mjd0 + fod;

prn = prnlist;
dat = dat(1:m, 1:length(prn));

end

function [mjd, prn, dat] = read_compact3(buf)

n = length(buf); % number of lines
dat = nan(n,99); % preallocate memory
sec = nan(n, 1); % preallocate memory

% GPS_START_TIME: start time
time = sscanf(buf{1},'%*s%f%f%f%f%f%f');
mjd0 = cal2mjd(time');

% the following lines are sat and data
prnlist =[];
i = 1; % index of buf
m = 0; % epoch number

while (i < n) % loop through the buf
    i = i + 1;
    line = buf{i};                  % list of the SVs
    if ~ischar(line); break; end;   % if end of the file, stop reading file
    
    m = m + 1;
    c = textscan(line,'%s');    % read the number of sats and sv numbers
    c = c{1};
    sec(m) = str2double(c(1));
    nsat   = str2double(c(2));
    
    if nsat == 0
        % if there are no sats, ignored
        continue;
    elseif nsat > 0
        % if there are sats
        prn = c(3:end);
        [~, ~, ib] = intersect(prnlist, prn);
        
        ii = true(length(prn),1);
        ii(ib,1) = false;
        prnlist = [prnlist; prn(ii)]; %#ok<AGROW>
        
        [~, ia, ib] = intersect(prnlist, prn);
        
    elseif nsat ~= -1
        error('Invalid line %d:\n%s', i+1, line);     
    end
    
    % if there is a line of observation data
    i = i + 1;
    line = buf{i};                  % list of the SVs
    if ~ischar(line); break; end;   % if end of the file, stop reading file
    
    [obs, nobs] = sscanf(line,'%f');		% read the data
    % there are some bugs in teqc, so we need to use number of sats in the epoch
    % to define the data to be stored
    num = min(length(ib), nobs);
    dat(m,ia(1:num)) = obs(ib(1:num))';
end

mjd = mjd0(1) + (mjd0(2)+sec)./86400;
mjd = mjd(1:m, 1);
prn = prnlist;
dat = dat(1:m, 1:length(prn));

end

function prn = str2prn(str)
% STR2PRN format satellite prn(string) to sat(number) used in GNSSLAB.

if isempty(str), prn = []; return; end

% prn shoule be strings
if(iscell(str)), str = char(str{:}); end
if ~ischar(str), error('prn must be strings'); end

str=[str repmat(' ', size(str,1), 3)];
prn = str(:,1:3);
prn = strjust(upper(prn), 'right');

ii = (prn(:,1)==' '); prn(ii,1) = 'G';
ii = (prn(:,2)==' '); prn(ii,2) = '0';

prn = cellstr(prn);

end