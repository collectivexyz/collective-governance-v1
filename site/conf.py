# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Collective Governance'
copyright = '2022, collective'
author = 'collective'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration


templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_static_path = ['_static', '_templates']


# read the docs
extensions = ['sphinx_rtd_theme']
html_theme = 'sphinx_rtd_theme'

html_context = {}

GENDOCFILE = 'site/_build/solcdoc.json'

def load_automated_docgen():
    """ 
    load external docgen docs from json

    NOTICE: exits on failure
    """
    from collections import OrderedDict
    import json
    import sys
    import traceback
    try:
        with open(GENDOCFILE, 'r') as gen_stream:
            gen_data = json.loads(gen_stream.read(), object_pairs_hook=OrderedDict)
            print('loading generated apidoc')
            for k, _ in gen_data.items():
                print(k)
            html_context['docgen'] = gen_data
    except Exception as e: 
        print('Failed to load: %s' % GENDOCFILE)
        print(e)
        traceback.print_stack()
        sys.exit(1)

def rstjinja(app, docname, source):
    """
    Render our pages as a jinja template for fancy templating goodness.
    """
    # Make sure we're outputting HTML
    if app.builder.format != 'html':
        return
    src = source[0]
    rendered = app.builder.templates.render_string(
        src, app.config.html_context
    )
    source[0] = rendered

def setup(app):
    """
    sphinx setup hook
    """
    load_automated_docgen()    
    app.connect('source-read', rstjinja)
