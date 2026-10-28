# The inputs in arrays (pages) of $size items, the last one possibly shorter
def paginate($size):

    # limit, not a recursion on input: each output of a recursion goes back
    # through all the previous calls, quadratic in the size of the pages
    def _paginate:
        [limit($size; inputs)] |
        if length == 0 then
            empty
        elif length == $size then
            ., _paginate
        end;

    _paginate;
