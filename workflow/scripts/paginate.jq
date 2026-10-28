def paginate($size):

    def _get_page($size):
        try
        (input |
        if $size > 1 then 
            ., _get_page($size-1)
        end)
        catch empty;

    def _paginate:
        [_get_page($size)] |
        if length == 0 then
            empty
        elif length == $size then
            ., _paginate
        end;

    _paginate;