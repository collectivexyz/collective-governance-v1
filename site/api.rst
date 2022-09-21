Contract Specification
======================

.. jinja template code to format the autodoc items for the contract specification
{% for contract, meta in docgen.items() %}
{%   if 'mergedoc' in meta %}

{{meta.name}}
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. _{{meta.name}}:

| **{{ meta.title }}**
| {{ meta.notice }}

    {% if 'interface' == meta['custom:type'] %}
.. object:: interface {{ meta.name }} 
    {% else %}
.. object:: contract {{ meta.name }}   
    {%- endif %}

    {% if meta['mergedoc']['methods'] %}
    {%      for method, notice in meta['mergedoc']['methods'].items() %}
  .. method:: {{ method }}
     
     {%         if 'params' in notice %}
     {%             for param, desc in notice['params'].items() %}
     :param {{ param }}: {{ desc }} 
     {%-            endfor %}
     {%-        endif %}
     {%         if 'returns' in notice %}
     {%              for return_key in ['_0', '_1', '_2', '_3', '_4', '_5', '_6', '_7', '_8', '_9'] %}
     {%                  if return_key in notice['returns'] %}
     :returns: {{ notice['returns'][return_key] }}
     {%-                 endif %}
     {%-             endfor %}
     {%-        endif %}
     {%         if 'details' in notice %}
     :notice: {{ notice['details'] }}
     {%-        endif %}

     {{ notice['notice'] }}
    {%-     endfor %}
    {%- endif %}
{%-   endif %}
{%- endfor %}
