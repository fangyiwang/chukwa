<%
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file 
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
%>
<%@ page import = "java.text.DecimalFormat,java.text.NumberFormat" %>
<%@ page import = "org.apache.hadoop.chukwa.util.XssFilter" %>

<%
    XssFilter xf = new XssFilter(request);
    NumberFormat nf = new DecimalFormat("###,###,###,##0.00");
    response.setHeader("boxId", xf.getParameter("boxId"));
    response.setContentType("text/html; chartset=UTF-8//IGNORE");
    String boxId=xf.getParameter("boxId");
    String cluster = (String) session.getAttribute("cluster");
%>
<html>
  <head>
  <link href="/hicc/css/default.css" rel="stylesheet" type="text/css">
  <link href="/hicc/css/formalize.css" rel="stylesheet" type="text/css">
  <script src="/hicc/js/jquery-1.3.2.min.js" type="text/javascript" charset="utf-8"></script>
  <script src="/hicc/js/jquery.formalize.js"></script>
  <script src="/hicc/js/autoHeight.js" type="text/javascript" charset="utf-8"></script>
  <script>
    function randString(n) {
      if(!n) {
        n = 5;
      }

      var text = '';
      var possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

      for(var i=0; i < n; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
      }

      return text;
    }

    var checkDataLength = function(curOption) {
      return function(data) {
        if (data.length == 0) {
          curOption.attr('disabled', 'disabled');
        }
      }
    };

    $.ajax({ url: "/hicc/v1/metrics/schema", dataType: "json", success: function(data){
      for(var i in data) {
        $('#table').append("<option>"+data[i]+"</option>");
      }
      // Look through each table option and see if it has anything in its family?
      $('#table').children().each(
        function() {
          var table = $(this).text();
          $.ajax({ url: encodeURI("/hicc/v1/metrics/schema/"+table), 
                   dataType: "json", 
                   success: checkDataLength($(this))
          });
        }
      );
    }});


    function getFamilies() {
      var size = $('#family option').size();
      $('#family').find('option').remove();
      var table = $('#table').val();
      $.ajax({ url: encodeURI("/hicc/v1/metrics/schema/"+table), dataType: "json", success: function(data){
        for(var i in data) {
          $('#family').append("<option>"+data[i]+"</option>");
        }
        // Look through each family option and see if it has any columns
        var table = $('#table').val();
        $('#family').children().each(
          function() {
            var family = $(this).text();
            $.ajax({ url: encodeURI("/hicc/v1/metrics/source/"+table), 
                     dataType: "json", 
                     success: checkDataLength($(this))
            });
          }
        );
      }});
    }

    function getColumns() {
      var size = $('#column option').size();
      $('#column').find('option').remove();
      var table = $('#table').val();
      var family = $('#family').val();
      $('#family :selected').each(function(i, selected) {
        var family = $(selected).val();
        var url = encodeURI("/hicc/v1/metrics/schema/"+table+"/"+family);
        var tableFamily = table+"/"+family;
        // Look through each column option and see if it has any rows
        $.ajax({ url: url, dataType: "json", success: function(data){
          for(var i in data) {
            $('#column').append(
              $("<option></option>")
                .attr("value", tableFamily+"/"+data[i])
                .text(data[i])
            );
          }
        }});
      });
    }

    function getRows() {
      var size = $('#row option').size();
      $('#row').find('option').remove();
      $('#chartType').html("");
      $('#family :selected').each(function(i, selected) {
        var metric = $(selected).val();
        var selection = metric+": <select id='ctype"+i+"'><option>lines</option><option>bars</option><option>points</option><option>area</option></select><br>";
        $('#chartType').append(selection);
      });
      $('#table :selected').each(function(i, selected) {
        var metricGroup = $(selected).val();
        var url = encodeURI("/hicc/v1/metrics/source/"+metricGroup);
        $.ajax({ url: url, dataType: "json", success: function(data){
          for(var i in data) {
            var test = $('#row').find('option[value="'+data[i]+'"]').val();
            if(typeof(test) == "undefined") {
              $('#row').append('<option value="'+data[i]+'">'+data[i]+'</option>');
            }
          }
        }});
      });
    }

    function buildChart() {
      var test = $('#row').val();
      if(test == null) {
        $('#row option:eq(0)').attr('selected',true);
      }
      var url = [];
      var idx = 0;
      $('#family :selected').each(function(i, selected) {
        var id = '#ctype' + i;
        var chartType = $(id).val();
        var chartTypeOption = { show: true };
        if (chartType=='area') {
          chartTypeOption = { show: true, fill: true };
        }
        $('#row :selected').each(function(j, rowSelected) {
          var s = { 'label' : $(selected).val() + "/" + $(rowSelected).val(), 'url' : encodeURI("/hicc/v1/metrics/series/" + $(selected).val() + "/" + $(rowSelected).val())};
          if(chartType=='area') {
            s['lines']=chartTypeOption;
          } else {
            s[chartType]=chartTypeOption;
          }
          url[idx++] = s;
        }); 
      });
      var title = $('#title').val();
      var ymin = $('#ymin').val() ;
      var ymax = $('#ymax').val();
      var yunit = $('#yunit').val();
      var data = { 'title' : title, 'yUnitType' : yunit, 'width' : 300, 'height' : 200, 'series' : url };
      if(ymin!='') {
        data['min']=ymin;
      }
      if(ymax!='') {
        data['max']=ymax;
      }
      return data;
    }

    function plot() {
      var data = buildChart();
      $.ajax({
        url: '/hicc/v1/chart/preview',
        type: 'PUT',
        contentType: 'application/json',
        data: JSON.stringify(data),
        success: function(result) {
          $('#graph')[0].src="about:blank";
          $('#graph')[0].contentWindow.document.open();
          $('#graph')[0].contentWindow.document.write(result);
          $('#graph')[0].contentWindow.document.close();
        }
      });
    }

    function publishChart() {
      var json = buildChart();
      var url = "/hicc/v1/chart/save";
      try {
        if($('#title').val()=="") {
          $("#title").val("Please provide a title");
          $("#title").addClass("error");
          $("#title").bind("click", function() {
            $("#title").val("");
            $("#title").removeClass("error");
            $("#title").unbind("click");
          });
          throw "no title provided.";
        }
      } catch(err) {
        console.log(err);
        return false;
      }
      $.ajax({ 
        type: "POST",
        url: url, 
        contentType : "application/json",
        data: JSON.stringify(json),
        success: function(data) {
          alert("Chart exported.");
        },
        fail: function(data) {
          alert("Chart export failed.");
        }
      });
    }
  </script>
  </head>
  <body>
    <form>
      <center>
      <table>
        <tr>
          <th>Metric Groups</th>
          <th>Metrics</th>
          <th>Sources</th>
          <th>Options</th>
          <th>Chart Type</th>
        </tr>
        <tr>
          <td>
            <select id="table" size="10" onMouseUp="getFamilies()" style="min-width: 100px;" class="select">
            </select>
          </td>
          <td>
            <select id="family" multiple size="10" style="min-width: 110px;" onMouseUp="getRows()">
            </select>
          </td>
          <td>
            <select id="row" size="10" style="min-width: 100px;">
            </select>
          </td>
          <td>
            <table>
              <tr>
                <td>
                  <label>Title</label>
                </td>
                <td>
                  <input type=text id="title">
                </td>
              </tr>
              <tr>
                <td>
                  <label>Y-axis Min</label>
                </td>
                <td>
                  <input type="text" id="ymin" />
                </td>
              </tr>
              <tr>
                <td>
                  <label>Y-axis Max</label>
                </td>
                <td>
                  <input type="text" id="ymax" />
                </td>
              </tr>
              <tr>
                <td>
                  <label>Y-axis Unit</label>
                </td>
                <td>
                  <select id="yunit">
                    <option>bytes</option>
                    <option>bytes-decimal</option>
                    <option value="ops">op/s</option>
                    <option value="percent">%</option>
                    <option>generic</option>
                  </select>
                </td>
              </tr>
            </table>
          </td>
          <td>
            <div id="chartType"></div>
          </td>
        </tr>
        <tr>
          <td>
            <input type=button name="action" value="Plot" onClick="plot()">
            <input type=button name="action" value="Publish" onClick="publishChart()">
          </td>
          <td>
          </td>
          <td>
          </td>
        </tr>
      </table>
    </form>
    <iframe id="graph" width="95%" class="autoHeight" height="70%" frameBorder="0" scrolling="no"></iframe>
    </center>
  </body>
</html>
