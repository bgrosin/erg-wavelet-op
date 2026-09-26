function ApplyTimeTicks(ax, theAxis)
%APPLYTIMETICKS  Uniform, offset-free time ticks for every panel.
%   Labels true theAxis time: stimulus at 0 for real OP records (pre-stim
%   negative), or 0..end for idealized records. The record start edge (the
%   pre-stim onset) is placed at the exact left limit so it always renders,
%   and xlim is locked to the data span so a panel and its spectrogram
%   share the same axis. Works for ANY start time, not just -40.

    t0 = min(theAxis);  t1 = max(theAxis);  span = t1 - t0;

    if     span <= 300,  step = 50;                       % OP-scale record
    elseif span <= 1200, step = 200;                      % ~1 s idealized
    else,                step = max(100, round(span/6/100)*100);  % long record
    end

    % interior grid of round ticks
    ticks = (ceil(t0/step)*step):step:t1;

    % mark the stimulus (t = 0) when it falls within the record
    if t0 <= 0 && t1 >= 0
        ticks = [ticks 0];
    end
    ticks(abs(ticks) < 1e-6) = 0;      % kill any "-0"
    ticks = unique(ticks);

    % Add the record start edge at the EXACT left limit (never clipped),
    % unless it would sit on top of the first grid tick.
    if isempty(ticks) || (ticks(1) - t0) > step/4
        ticks = [t0 ticks];
    end

    labels = compose('%g', round(ticks));   % integer labels; edge = round(t0)
    set(ax, 'XTick', ticks, 'XTickLabel', labels);
    xlim(ax, [t0 t1]);
end
