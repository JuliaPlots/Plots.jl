
# Here comes the specification of when which recipe is processed.
# It contains functions before and after every stage for interaction with the plotting package.

function recipe_pipeline(plt,             # frontend specific representation of a plot
                         plotattributes,  # current state of recipe keywords
                         args,            # set of arguments passed by the user
  )
  _recipe_init(plt, plotattributes, args)
  kw_list = _process_userrecipes(plt, plotattributes, args)
  _recipe_after_user(plt, plotattributes, args)
  kw_list = _process_plotrecipes(plt, plotattributes, args)
  _recipe_after_plot(plt, plotattributes, args)
  for (series_ind, series) in enumerate(series_list)
    kw_list = _process_seriesrecipe(plt, plotattributes)
    _recipe_after_series(plt, plotattributes, series_ind)
  end
  _recipe
end
