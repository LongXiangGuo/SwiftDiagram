/* ================================================================
   SwiftClassDiagram Web Console — 逻辑
   分层架构 + GOF 设计模式：
   - L1 Schema 层：HELP（帮助注册表）+ TEMPLATE（模板字段骨架）
   - L2 State 层：Store（配置数据模型 + 深合并 / 收集）
   - L3 View 层：ControlFactory（工厂）+ FormBuilder（构建器）+ TagInput 组件
   - L4 Controller 层：Commands（命令模式）+ Resizer（拖拽）+ ImageView（图片）
   ================================================================ */

/* ================================================================
   L1 · Schema 层：帮助文案注册表 + 模板字段骨架
   ================================================================ */
var HELP = {
  'files': '文件收集规则：控制哪些 Swift 源文件纳入类图分析。',
  'files.include': '需要纳入类图分析的源文件路径（相对当前目录）。支持通配符 *。为空表示扫描整个目录。',
  'files.exclude': '从分析中排除的源文件路径。支持通配符 *，例如 Sources/**/Demo/**。',
  'elements': '全局元素规则（最低优先级 P0）：过滤类型与成员、控制展示开关、五类关系配置。',
  'elements.exclude': '从类图中过滤掉这些类型及其全部信息（属性、方法、关系）。支持通配符 *。',
  'elements.havingAccessLevel': '过滤「类型本身」的访问级别。勾选 = 允许展示该类；package 归入 internal。',
  'elements.showMembersWithAccessLevel': '过滤「成员（属性/方法）」的访问级别输出。勾选 = 该级别成员会展示。',
  'elements.showNestedTypes': '是否展示嵌套类型（类型内部定义的类型）。默认关闭。',
  'elements.showExtensions': '是否展示该类型声明的扩展（extension）。默认关闭。',
  'elements.showGenerics': '是否展示类型引用的泛型参数。默认关闭。',
  'elements.relationships': '五类关系的总开关与排除名单。仅继承关系默认开启，其余默认关闭。',
  'elements.relationships.inheritance': '继承关系（父类 + 协议实现），符号 <|--。exclude 可排除指定目标类型（支持 *）。',
  'elements.relationships.association': '关联关系（方法签名中依赖的类型），符号 -->。默认关闭。',
  'elements.relationships.aggregation': '聚合关系（属性/初始化器依赖，非拥有语义），符号 o--。默认关闭。',
  'elements.relationships.composition': '组合关系（属性/初始化器依赖，拥有语义），符号 *--。默认关闭。',
  'elements.relationships.dependency': '扩展依赖关系（extension），符号 <..。默认关闭。',
  'rel.toggle': '是否绘制该类关系。三态：未设置 / 开启 / 关闭。group 级未设置时继承全局。',
  'rel.exclude': '排除的目标类型名单，支持通配符 *。group 级可用 $(inherit) 表示「继承全局 exclude 并追加」。',
  'groupSettings': '分组设置：按文件夹将类型聚合为 UML 图上的 package。',
  'groupSettings.groups': '分组定义列表。enable=false 的分组不绘制 package、不应用任何覆盖规则；enable=true 才生效。',
  'group.name': '分组名称（PlantUML package 标题）。',
  'group.folder': '归属该分组的文件夹路径。支持通配符 *，可从下拉列表选择当前目录的一级目录。',
  'group.enable': '开启该分组：绘制 package 并应用 group 级覆盖规则。',
  'groupSettings.elements': 'group 级 elements 覆盖（优先级 P1/P2）。仅当存在至少一个 enable=true 的 group 且下方总开关为 true 时生效。',
  'groupSettings.elements.enable': 'group 级覆盖总开关。开启后，下方各「覆盖全局」项才会生效。',
  'groupSettings.elements.override': '勾选「覆盖全局」后设置该值，覆盖全局 elements 配置；不勾选则继承全局。',
  'groupSettings.elements.exclude': '覆盖全局 exclude 名单。含 $(inherit) token 时 = 继承全局 exclude 并追加。',
  'groupSettings.elements.havingAccessLevel': '覆盖全局「类型访问级别」过滤。',
  'groupSettings.elements.showMembersWithAccessLevel': '覆盖全局「成员访问级别」过滤。',
  'groupSettings.elements.showNestedTypes': '覆盖全局「是否展示嵌套类型」。',
  'groupSettings.elements.showExtensions': '覆盖全局「是否展示扩展」。',
  'groupSettings.elements.showGenerics': '覆盖全局「是否展示泛型」。',
  'groupSettings.elements.relationships': '覆盖全局关系配置（最高优先级 P2）。',
  'groupSettings.crossGroupRelationships': '跨 group 关系规则：控制不同 group 之间哪些关系类型允许绘制。为 false 的关系被裁剪；开启单行聚合时聚合并为 group 间单行链接。',
  'cgr.singleLine': '单行聚合选项：把跨 group 关系合并为 group 之间的单行链接，防止线条爆量。',
  'cgr.singleLine.excludeSameGroup': '同一个 group 内的元素关系不受单行聚合影响（默认 true）。',
  'cgr.singleLine.allGroups': '任意跨 group 关系对只输出一条 "GroupA" -- "GroupB" 单行链接（默认 true）。',
  'skinparamCommands': 'PlantUML skinparam 命令，改变绘制的颜色与字体。每行一条。例如 skinparam shadow false。'
};

// 完整模板字段骨架：渲染时与配置数据深合并，保证表单展示全部模板属性
var TEMPLATE = {
  files: { include: [], exclude: [] },
  elements: {
    exclude: [],
    havingAccessLevel: { open: true, 'public': true, 'internal': true, 'fileprivate': false, 'private': false },
    showMembersWithAccessLevel: { open: true, 'public': true, 'internal': true, 'fileprivate': false, 'private': false },
    showNestedTypes: false,
    showExtensions: false,
    showGenerics: false,
    relationships: {
      inheritance: { toggle: true, exclude: [] },
      association: { toggle: null, exclude: [] },
      aggregation: { toggle: null, exclude: [] },
      composition: { toggle: null, exclude: [] },
      dependency: { toggle: null, exclude: [] }
    }
  },
  groupSettings: {
    groups: [],
    elements: { enable: false },
    crossGroupRelationships: {
      inheritance: false, association: false, aggregation: false,
      composition: false, dependency: false,
      singleLine: { excludeSameGroup: true, allGroups: true }
    }
  },
  skinparamCommands: ['skinparam shadow false', 'skinparam classWidth 120']
};

var REL_ORDER = ['inheritance', 'association', 'aggregation', 'composition', 'dependency'];
var REL_LABEL = { inheritance: '继承', association: '关联', aggregation: '聚合', composition: '组合', dependency: '依赖' };
var ACCESS_ORDER = ['open', 'public', 'internal', 'fileprivate', 'private'];
var ACCESS_LABEL = { open: 'open', 'public': 'public', internal: 'internal', fileprivate: 'fileprivate', private: 'private' };
// group 级可覆盖的可选字段（缺失 = 继承全局）
var OVERRIDE_KEYS = ['exclude', 'havingAccessLevel', 'showMembersWithAccessLevel', 'showNestedTypes', 'showExtensions', 'showGenerics', 'relationships'];

/* ================================================================
   L2 · State 层：配置数据模型（深合并 / 路径读写 / 收集）
   ================================================================ */
var Store = {
  config: null,
  dirs: [],
  types: [],
  mode: 'form',
  path: '',
  textLoaded: false,

  get: function(path, fallback) {
    var cur = Store.config;
    if (!cur) return fallback;
    var parts = path.split('.');
    for (var i = 0; i < parts.length; i++) {
      if (cur === null || cur === undefined) return fallback;
      cur = cur[parts[i]];
    }
    return cur === undefined ? fallback : cur;
  },

  has: function(path) {
    var cur = Store.config;
    if (!cur) return false;
    var parts = path.split('.');
    for (var i = 0; i < parts.length; i++) {
      if (cur === null || cur === undefined) return false;
      cur = cur[parts[i]];
    }
    return cur !== undefined && cur !== null;
  },

  // 渲染用：配置值 → 模板默认值（深合并）
  merged: function() {
    function mergeDeep(tpl, cfg) {
      var out = {};
      for (var k in tpl) {
        var tv = tpl[k], cv = cfg && cfg[k];
        if (tv !== null && typeof tv === 'object' && !Array.isArray(tv)) {
          out[k] = mergeDeep(tv, cv);
        } else {
          out[k] = cv !== undefined ? cv : tv;
        }
      }
      return out;
    }
    var base = mergeDeep(TEMPLATE, Store.config || {});
    // groupSettings.elements 仅保留 enable + 配置中实际存在的覆盖键
    var ge = (Store.config && Store.config.groupSettings && Store.config.groupSettings.elements) || {};
    base.groupSettings.elements = { enable: ge.enable === true, _overrides: {} };
    OVERRIDE_KEYS.forEach(function(k) { if (ge[k] !== undefined) base.groupSettings.elements._overrides[k] = ge[k]; });
    return base;
  }
};

/* ================================================================
   L3 · View 层：ControlFactory（工厂）+ FormBuilder（构建器）
   ================================================================ */
var UI = {
  // -- 工具：创建元素 --（GoF Factory Method）
  el: function(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  },

  // 字段标签（含 ? 帮助按钮，点击显示帮助）
  label: function(text, helpKey) {
    var l = UI.el('div', 'flabel');
    var b = UI.el('b', null, text);
    l.appendChild(b);
    if (helpKey && HELP[helpKey]) {
      var h = UI.el('button', 'help', '?');
      h.title = '点击查看帮助';
      h.onclick = function(e) { e.stopPropagation(); Tooltip.show(helpKey, h); };
      l.appendChild(h);
    }
    return l;
  },

  // 字符串数组控件：skinparamCommands 用行编辑 textarea；include/exclude 用 TagInput（联想 + Enter 确认）
  arrayField: function(path, value, label, helpKey, placeholder) {
    var w = UI.el('div', 'field');
    w.appendChild(UI.label(label, helpKey));
    var isSkin = path.indexOf('skinparam') === 0;
    if (isSkin) {
      var ta = UI.el('textarea', 'line-array');
      ta.dataset.path = path;
      ta.placeholder = placeholder || '每行一条命令';
      ta.value = (value || []).join('\n');
      w.appendChild(ta);
    } else {
      var box = UI.el('div');
      box.dataset.path = path;
      createTagInput(box, {
        values: (value || []),
        suggestGet: function() { return path.indexOf('files.') === 0 ? Store.dirs : Store.types; },
        placeholder: placeholder || '输入后按 Enter 确认；输入时可联想类名'
      });
      w.appendChild(box);
    }
    return w;
  },

  // 布尔控件
  boolField: function(path, value, label, helpKey) {
    var w = UI.el('div', 'field');
    w.appendChild(UI.label(label, helpKey));
    var c = UI.el('input');
    c.type = 'checkbox';
    c.checked = !!value;
    c.dataset.path = path;
    w.appendChild(c);
    return w;
  },

  // 三态关系开关（未设置 / 开启 / 关闭）
  triSelect: function(path, value, helpKey) {
    var s = UI.el('select', 'tri');
    s.dataset.path = path;
    var opts = [['', '未设置'], ['true', '开启'], ['false', '关闭']];
    opts.forEach(function(o) {
      var op = UI.el('option', null, o[1]);
      op.value = o[0];
      if (String(value) === o[0]) op.selected = true;
      s.appendChild(op);
    });
    return s;
  },

  // 五访问级别复选框行
  accessFilter: function(path, filter, label, helpKey) {
    var w = UI.el('div', 'field');
    w.appendChild(UI.label(label, helpKey));
    var chips = UI.el('div', 'chips');
    ACCESS_ORDER.forEach(function(k) {
      var lab = UI.el('label');
      var c = UI.el('input');
      c.type = 'checkbox';
      c.checked = !!(filter && filter[k]);
      c.dataset.path = path + '.' + k;
      lab.appendChild(c);
      lab.appendChild(document.createTextNode(ACCESS_LABEL[k]));
      chips.appendChild(lab);
    });
    w.appendChild(chips);
    return w;
  },

  // 五类关系编辑区（toggle 三态 + exclude TagInput）
  relationships: function(basePath, rels) {
    var box = UI.el('div', 'nested');
    REL_ORDER.forEach(function(k) {
      var row = UI.el('div', 'rel-row');
      var nm = UI.el('div', 'rel-name');
      var b = UI.el('b', null, REL_LABEL[k]);
      nm.appendChild(b);
      var h = UI.el('button', 'help', '?');
      h.onclick = function(e) { e.stopPropagation(); Tooltip.show('elements.relationships.' + k, h); };
      nm.appendChild(h);
      row.appendChild(nm);
      var r = (rels && rels[k]) || {};
      row.appendChild(UI.triSelect(basePath + '.' + k + '.toggle', r.toggle, null));
      var box2 = UI.el('div');
      box2.dataset.path = basePath + '.' + k + '.exclude';
      createTagInput(box2, {
        values: (r.exclude || []),
        suggestGet: function() { return Store.types; },
        placeholder: '排除类型，Enter 确认'
      });
      row.appendChild(box2);
      box.appendChild(row);
    });
    var hk = UI.el('div', 'hint');
    hk.textContent = 'toggle：三态开关；exclude：排除名单（group 级可用 $(inherit) 继承全局）';
    box.appendChild(hk);
    return box;
  },

  // -- FormBuilder：渲染整体表单 --（GoF Builder）
  build: function() {
    var data = Store.merged();
    var root = document.getElementById('formRoot');
    root.innerHTML = '';

    root.appendChild(UI.section('files', '文件收集规则 (files)', function(body) {
      var f = data.files || {};
      body.appendChild(UI.arrayField('files.include', f.include, 'include — 包含', 'files.include'));
      body.appendChild(UI.arrayField('files.exclude', f.exclude, 'exclude — 排除', 'files.exclude'));
    }));

    root.appendChild(UI.section('elements', '元素规则 (elements)', function(body) {
      var e = data.elements || {};
      body.appendChild(UI.arrayField('elements.exclude', e.exclude, 'exclude — 排除类型', 'elements.exclude'));
      body.appendChild(UI.accessFilter('elements.havingAccessLevel', e.havingAccessLevel, 'havingAccessLevel — 类型访问级别', 'elements.havingAccessLevel'));
      body.appendChild(UI.accessFilter('elements.showMembersWithAccessLevel', e.showMembersWithAccessLevel, 'showMembersWithAccessLevel — 成员访问级别', 'elements.showMembersWithAccessLevel'));
      body.appendChild(UI.boolField('elements.showNestedTypes', e.showNestedTypes, 'showNestedTypes — 嵌套类型', 'elements.showNestedTypes'));
      body.appendChild(UI.boolField('elements.showExtensions', e.showExtensions, 'showExtensions — 扩展', 'elements.showExtensions'));
      body.appendChild(UI.boolField('elements.showGenerics', e.showGenerics, 'showGenerics — 泛型', 'elements.showGenerics'));
      var wrap = UI.el('div', 'field');
      wrap.appendChild(UI.label('relationships — 关系配置', 'elements.relationships'));
      wrap.appendChild(UI.relationships('elements.relationships', e.relationships));
      body.appendChild(wrap);
    }));

    root.appendChild(UI.section('groupSettings', '分组设置 (groupSettings)', function(body) {
      body.appendChild(UI.groupList(data.groupSettings.groups));
      body.appendChild(UI.groupElements(data.groupSettings.elements));
      body.appendChild(UI.crossGroup(data.groupSettings.crossGroupRelationships));
    }));

    root.appendChild(UI.section('skinparamCommands', '皮肤命令 (skinparamCommands)', function(body) {
      body.appendChild(UI.arrayField('skinparamCommands', data.skinparamCommands, 'skinparamCommands — PlantUML skinparam', 'skinparamCommands', '每行一条 skinparam 命令'));
    }));
  },

  // 折叠区（details/summary）
  section: function(id, title, bodyFn) {
    var d = UI.el('details', 'section');
    d.open = true;
    var sum = UI.el('summary', null, title);
    d.appendChild(sum);
    var body = UI.el('div', 'body');
    bodyFn(body);
    d.appendChild(body);
    return d;
  },

  // -- group 列表：默认候选（enable:false）+ 自定义添加 + folder 下拉 --
  groupList: function(groups) {
    var w = UI.el('div', 'field');
    var head = UI.label('groups — 分组列表', 'groupSettings.groups');
    var addBtn = UI.el('button', 'small');
    addBtn.textContent = '+ 添加分组';
    addBtn.style.marginLeft = 'auto';
    addBtn.onclick = function() { Cmd.addGroup(); };
    head.appendChild(addBtn);
    w.appendChild(head);
    var hint = UI.el('div', 'hint');
    hint.textContent = '默认以当前目录一级子目录生成（未启用）。勾选「启用」后分组才会绘制 package。';
    w.appendChild(hint);
    var list = UI.el('div', 'glist');
    (groups || []).forEach(function(g, i) { list.appendChild(UI.groupCard(g, i)); });
    w.appendChild(list);
    return w;
  },

  groupCard: function(g, i) {
    var card = UI.el('div', 'gcard' + (g.enable ? '' : ' disabled'));
    card.dataset.group = i;
    var head = UI.el('div', 'ghead');
    var en = UI.el('label', 'g-enable');
    var cb = UI.el('input');
    cb.type = 'checkbox';
    cb.checked = !!g.enable;
    cb.dataset.gf = 'enable';
    cb.onchange = function() { Cmd.toggleGroup(i); };
    en.appendChild(cb);
    en.appendChild(document.createTextNode('启用'));
    head.appendChild(en);
    var badge = UI.el('span', 'badge' + (g.enable ? ' on' : ''), g.enable ? '已启用' : '未启用');
    head.appendChild(badge);
    var nm = UI.el('b', null, g.name || ('分组 ' + (i + 1)));
    head.appendChild(nm);
    var del = UI.el('button', 'small', '删除');
    del.onclick = function() { Cmd.removeGroup(i); };
    head.appendChild(del);
    card.appendChild(head);
    var grow = UI.el('div', 'grow');
    var nameInput = UI.el('input');
    nameInput.type = 'text';
    nameInput.dataset.gf = 'name';
    nameInput.value = g.name || '';
    nameInput.placeholder = '分组名称';
    nameInput.title = '分组名称（package 标题）';
    grow.appendChild(nameInput);
    var folderInput = UI.el('input');
    folderInput.type = 'text';
    folderInput.dataset.gf = 'folder';
    folderInput.value = g.folder || '';
    folderInput.placeholder = '文件夹路径（可从下拉选择）';
    folderInput.setAttribute('list', 'dir-list');
    folderInput.title = '归属文件夹（可从下拉选择）';
    grow.appendChild(folderInput);
    card.appendChild(grow);
    return card;
  },

  // -- group 级 elements 覆盖（P1/P2）--
  groupElements: function(ge) {
    var w = UI.el('div', 'field');
    w.appendChild(UI.label('group 级 elements 覆盖 (P1/P2)', 'groupSettings.elements'));
    var master = UI.el('div', 'field');
    master.appendChild(UI.boolField('groupSettings.elements.enable', ge.enable, 'enable — 覆盖总开关', 'groupSettings.elements.enable'));
    w.appendChild(master);
    var hint = UI.el('div', 'hint');
    hint.textContent = '总开关开启后，下方各项勾选「覆盖全局」才生效；未覆盖的项继承全局 elements。';
    w.appendChild(hint);
    var box = UI.el('div', 'nested');
    OVERRIDE_KEYS.forEach(function(k) {
      box.appendChild(UI.overrideField('groupSettings.elements.' + k, ge._overrides[k], k));
    });
    w.appendChild(box);
    return w;
  },

  // 覆盖全局控件（GoF Bridge：继承状态 ↔ 显式设置状态）
  overrideField: function(path, value, key) {
    var wrap = UI.el('div', 'override' + (value !== undefined ? ' on' : ''));
    wrap.dataset.ov = path;
    var lab = UI.el('label', 'ov-master');
    var cb = UI.el('input');
    cb.type = 'checkbox';
    cb.checked = value !== undefined;
    cb.className = 'ov-master-cb';
    cb.onchange = function() {
      wrap.classList.toggle('on', cb.checked);
      body.style.display = cb.checked ? 'block' : 'none';
    };
    lab.appendChild(cb);
    lab.appendChild(document.createTextNode('覆盖全局'));
    lab.appendChild(UI.helpButton('groupSettings.elements.' + key));
    wrap.appendChild(lab);
    var body = UI.el('div', 'ov-body');
    body.style.display = value !== undefined ? 'block' : 'none';
    var lbl = { exclude: 'exclude — 排除类型', havingAccessLevel: 'havingAccessLevel — 类型访问级别', showMembersWithAccessLevel: 'showMembersWithAccessLevel — 成员访问级别', showNestedTypes: 'showNestedTypes — 嵌套类型', showExtensions: 'showExtensions — 扩展', showGenerics: 'showGenerics — 泛型', relationships: 'relationships — 关系配置' }[key];
    if (key === 'exclude') {
      body.appendChild(UI.arrayField(path, value, lbl, 'groupSettings.elements.exclude'));
    } else if (key === 'havingAccessLevel' || key === 'showMembersWithAccessLevel') {
      body.appendChild(UI.accessFilter(path, value, lbl, 'groupSettings.elements.' + key));
    } else if (key === 'relationships') {
      var fw = UI.el('div', 'field');
      fw.appendChild(UI.label(lbl, 'groupSettings.elements.relationships'));
      fw.appendChild(UI.relationships(path, value));
      body.appendChild(fw);
    } else {
      var sf = UI.el('div', 'field');
      sf.appendChild(UI.label(lbl, 'groupSettings.elements.' + key));
      sf.appendChild(UI.triSelect(path, value));
      body.appendChild(sf);
    }
    wrap.appendChild(body);
    return wrap;
  },

  helpButton: function(helpKey) {
    var h = UI.el('button', 'help', '?');
    h.onclick = function(e) { e.stopPropagation(); Tooltip.show(helpKey, h); };
    return h;
  },

  // -- 跨 group 关系 --
  crossGroup: function(cgr) {
    var w = UI.el('div', 'field');
    w.appendChild(UI.label('crossGroupRelationships — 跨组关系', 'groupSettings.crossGroupRelationships'));
    var box = UI.el('div', 'nested');
    var chips = UI.el('div', 'chips');
    REL_ORDER.forEach(function(k) {
      var lab = UI.el('label');
      var c = UI.el('input');
      c.type = 'checkbox';
      c.checked = !!(cgr && cgr[k]);
      c.dataset.path = 'groupSettings.crossGroupRelationships.' + k;
      lab.appendChild(c);
      lab.appendChild(document.createTextNode(REL_LABEL[k]));
      chips.appendChild(lab);
    });
    box.appendChild(chips);
    box.appendChild(UI.label('singleLine — 单行聚合', 'cgr.singleLine'));
    var sline = UI.el('div', 'chips');
    [['excludeSameGroup', 'cgr.singleLine.excludeSameGroup', '排除同组'], ['allGroups', 'cgr.singleLine.allGroups', '全部聚合']].forEach(function(t) {
      var lab = UI.el('label');
      var c = UI.el('input');
      c.type = 'checkbox';
      c.checked = !!(cgr && cgr.singleLine && cgr.singleLine[t[0]]);
      c.dataset.path = 'groupSettings.crossGroupRelationships.singleLine.' + t[0];
      lab.appendChild(c);
      lab.appendChild(document.createTextNode(t[2]));
      sline.appendChild(lab);
    });
    box.appendChild(sline);
    w.appendChild(box);
    return w;
  }
};

/* ================================================================
   TagInput 组件：tag 按钮 + Enter 换行 + 联想下拉 + 焦点展开
   GoF Mediator：集中处理输入/联想/删除的交互协调
   ================================================================ */
function createTagInput(container, opts) {
  container.classList.add('tag-input');
  container.dataset.tag = '1';
  var editor = UI.el('input');
  editor.type = 'text';
  editor.className = 'tag-editor';
  editor.placeholder = opts.placeholder || '输入后按 Enter 确认';
  var suggest = UI.el('div', 'suggest');
  var items = [];
  var activeIndex = -1;
  var debounceTimer = null;
  var BLUR_DELAY = 150;
  var DEBOUNCE_DELAY = 120;

  // 输入框宽度随内容自适应：正在输入的文本必须完整可见，不挤压、不截断
  function resizeEditor() {
    var minW = editor.placeholder ? Math.min(200, editor.placeholder.length * 7 + 16) : 100;
    var w = editor.value ? Math.max(minW, editor.scrollWidth + 6) : minW;
    editor.style.width = w + 'px';
  }

  function renderTags() {
    container.querySelectorAll('.tag').forEach(function(t) { t.remove(); });
    (opts.values || []).forEach(function(v) {
      var span = UI.el('span', 'tag');
      span.dataset.value = v;
      span.textContent = v;
      var x = UI.el('button', 'tag-x', '×');
      x.title = '删除';
      x.onclick = function() {
        var idx = opts.values.indexOf(v);
        if (idx >= 0) opts.values.splice(idx, 1);
        renderTags();
        refreshSuggest();
      };
      span.appendChild(x);
      container.insertBefore(span, editor);
    });
  }

  // 下拉定位（position:fixed，挂 body）：按输入框视口坐标对齐，内容不足一屏全部亮显；
  // 快超出屏幕时限制高度滚动，下方空间不足则向上展开。随滚动/缩放实时跟随。
  function positionSuggest() {
    var needed = suggest.scrollHeight;
    var rect = container.getBoundingClientRect();
    suggest.style.position = 'fixed';
    suggest.style.width = Math.max(rect.width, 180) + 'px';
    suggest.style.left = Math.max(4, rect.left) + 'px';
    var spaceBelow = window.innerHeight - rect.bottom - 8;
    var spaceAbove = rect.top - 8;
    var openUp = spaceBelow < Math.min(needed, 220) && spaceAbove > spaceBelow;
    var top, bottom, maxH;
    if (openUp && spaceAbove >= 60) {
      top = 'auto';
      bottom = Math.max(0, window.innerHeight - rect.top + 4) + 'px';
      maxH = Math.max(60, spaceAbove) + 'px';
    } else {
      // 输入框可能已滚出视口，夹取下拉到视口内
      top = Math.min(Math.max(4, rect.bottom + 4), window.innerHeight - 60) + 'px';
      bottom = 'auto';
      maxH = Math.max(60, Math.min(needed, spaceBelow)) + 'px';
    }
    suggest.style.top = top;
    suggest.style.bottom = bottom;
    suggest.style.maxHeight = maxH;
  }

  function refreshSuggest() {
    var candidates = (opts.suggestGet && opts.suggestGet()) || [];
    var q = editor.value.trim();
    var existing = opts.values || [];
    var list = q
      ? candidates.filter(function(c) { return c.toLowerCase().indexOf(q.toLowerCase()) !== -1; })
      : candidates.slice();
    // 已添加的 tag 不再出现在联想列表，避免重复选择
    list = list.filter(function(c) { return existing.indexOf(c) === -1; });
    list = list.slice(0, 50);
    suggest.innerHTML = '';
    activeIndex = -1;
    if (!list.length) {
      suggest.style.display = 'none';
      return;
    }
    list.forEach(function(c, i) {
      var it = UI.el('div', 's-item');
      it.textContent = c;
      it.onmousedown = function(e) { e.preventDefault(); pick(c); };
      it.onmouseenter = function() { activeIndex = i; highlight(); };
      suggest.appendChild(it);
    });
    items = list;
    suggest.style.display = 'block';
    highlight();
    positionSuggest();
  }

  function hideSuggest() { suggest.style.display = 'none'; activeIndex = -1; }

  function highlight() {
    Array.prototype.forEach.call(suggest.children, function(ch, i) {
      ch.classList.toggle('active', i === activeIndex);
    });
  }

  // 选中联想项：填入输入框（可继续编辑补充），下拉随之关闭
  function pick(v) {
    editor.value = v;
    hideSuggest();
    resizeEditor();
    editor.focus();
  }

  function commit() {
    var v = editor.value.trim();
    if (!v) return;
    opts.values.push(v);
    editor.value = '';
    renderTags();
    resizeEditor();
    refreshSuggest();
  }

  // 防抖：避免每次击键都重建下拉列表
  function scheduleSuggest() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(refreshSuggest, DEBOUNCE_DELAY);
  }

  // 下拉打开期间跟随滚动/缩放/容器内部滚动
  function reposition() {
    if (suggest.style.display === 'block') positionSuggest();
  }
  window.addEventListener('scroll', reposition, true);
  window.addEventListener('resize', reposition);
  container.addEventListener('scroll', reposition);

  container.addEventListener('click', function() { editor.focus(); });
  editor.addEventListener('focus', function() {
    container.classList.add('expanded');
    resizeEditor();
    refreshSuggest();
  });
  editor.addEventListener('blur', function() {
    setTimeout(function() {
      if (editor.value.trim()) commit();
      container.classList.remove('expanded');
      hideSuggest();
      resizeEditor();
    }, BLUR_DELAY);
  });
  editor.addEventListener('input', function() {
    resizeEditor();
    scheduleSuggest();
  });
  editor.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      // 若联想仍在防抖排队，先同步刷新，避免选到旧列表
      if (debounceTimer) { clearTimeout(debounceTimer); refreshSuggest(); }
      if (suggest.style.display === 'block' && activeIndex >= 0 && items[activeIndex]) {
        pick(items[activeIndex]);
      } else {
        commit();
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (suggest.style.display === 'block' && items.length) {
        activeIndex = (activeIndex + 1) % items.length;
        highlight();
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (suggest.style.display === 'block' && items.length) {
        activeIndex = (activeIndex - 1 + items.length) % items.length;
        highlight();
      }
    } else if (e.key === 'Backspace' && editor.value === '' && opts.values.length) {
      opts.values.pop();
      renderTags();
      refreshSuggest();
    }
  });

  container.appendChild(editor);
  // 下拉挂到 body，避免被 .tag-input 的 overflow:auto 裁剪（position:fixed 按视口定位）
  document.body.appendChild(suggest);
  // renderTags 依赖 insertBefore(span, editor)，必须等 editor 已挂载后再调用
  renderTags();
  resizeEditor();
}

/* ================================================================
   Tooltip：帮助浮层组件（点击字段 ? 按钮弹出）
   ================================================================ */
var Tooltip = {
  show: function(helpKey, anchor) {
    var tip = document.getElementById('tooltip');
    var text = HELP[helpKey] || '暂无帮助';
    tip.innerHTML = text.replace(/`([^`]+)`/g, '<code>$1</code>');
    tip.style.display = 'block';
    var rect = anchor.getBoundingClientRect();
    var top = rect.bottom + 6;
    if (top + tip.offsetHeight > window.innerHeight) top = rect.top - tip.offsetHeight - 6;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 10);
    tip.style.top = top + 'px';
    tip.style.left = Math.max(8, left) + 'px';
  },
  hide: function() {
    document.getElementById('tooltip').style.display = 'none';
  }
};
document.addEventListener('click', function(e) {
  if (!e.target.closest('.help')) Tooltip.hide();
});
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    Tooltip.hide();
    Lightbox.close();
    // 退出首页卡片与全屏预览的拖动模式
    cardPanModes.forEach(function(off) { off(); });
  }
});

/* ================================================================
   L4 · Controller 层：命令模式（GoF Command）
   ================================================================ */
var Cmd = {
  // ---- 收集表单 → 配置对象 ----
  collect: function() {
    var result = {};
    document.querySelectorAll('[data-path]').forEach(function(el) {
      var v = UI.readControl(el);
      if (v === undefined || v === null) return;
      var path = el.dataset.path;
      // override 容器内的控件仅在 master 勾选时收集
      var ov = el.closest('.override');
      if (ov) {
        var master = ov.querySelector('.ov-master-cb');
        if (master && !master.checked) return;
      }
      setAtPath(result, path, v);
    });
    // group 列表（独立收集）
    var groups = [];
    document.querySelectorAll('[data-group]').forEach(function(card) {
      var g = {};
      card.querySelectorAll('[data-gf]').forEach(function(el) {
        var f = el.dataset.gf;
        if (f === 'enable') g.enable = el.checked;
        else g[f] = el.value.trim();
      });
      if (g.name || g.folder) groups.push({ name: g.name || '', folder: g.folder || '', enable: !!g.enable });
    });
    if (groups.length) result.groupSettings.groups = groups;
    return cleanup(result);
  },

  // ---- 模式切换 ----
  switchMode: function(mode) {
    Store.mode = mode;
    document.getElementById('formMode').style.display = mode === 'form' ? '' : 'none';
    document.getElementById('textMode').style.display = mode === 'text' ? '' : 'none';
    document.querySelectorAll('#tabs button').forEach(function(b) {
      b.classList.toggle('active', b.dataset.mode === mode);
    });
    if (mode === 'text' && !Store.textLoaded) Cmd.load();
  },

  // ---- 加载配置 + 候选目录 + 类型名 ----
  load: function() {
    var pending = 4;
    var done = function(msg) { pending--; if (pending <= 0 && msg) setStatus(msg, false); };
    fetch('/api/config').then(function(r) { return r.json(); }).then(function(d) {
      if (!d.ok) { setStatus(d.message, true); done(); return; }
      document.getElementById('path').textContent = d.path;
      Store.config = d.config;
      Store.textLoaded = false;
      var groups = d.config && d.config.groupSettings && d.config.groupSettings.groups;
      if (!groups || !groups.length) {
        if (Store.dirs.length) {
          Store.config.groupSettings = Store.config.groupSettings || {};
          Store.config.groupSettings.groups = Store.dirs.map(function(dir) { return { name: dir, folder: dir, enable: false }; });
        }
      }
      UI.build();
      done();
    }).catch(function() { setStatus('加载失败', true); done(); });
    fetch('/api/config-text').then(function(r) { return r.json(); }).then(function(d) {
      if (d.ok) document.getElementById('config').value = d.content;
      Store.textLoaded = true;
      done();
    }).catch(function() { done(); });
    fetch('/api/dirs').then(function(r) { return r.json(); }).then(function(d) {
      if (d.ok) {
        Store.dirs = d.dirs || [];
        fillDirList(Store.dirs);
        var groups = Store.config && Store.config.groupSettings && Store.config.groupSettings.groups;
        if (Store.config && (!groups || !groups.length) && d.dirs.length) {
          Store.config.groupSettings = Store.config.groupSettings || {};
          Store.config.groupSettings.groups = d.dirs.map(function(dir) { return { name: dir, folder: dir, enable: false }; });
          UI.build();
        }
      }
      done();
    }).catch(function() { done(); });
    fetch('/api/types').then(function(r) { return r.json(); }).then(function(d) {
      if (d.ok) Store.types = d.types || [];
      done();
    }).catch(function() { done(); });
  },

  // ---- 生成预览 ----
  preview: function() {
    setStatus('正在生成预览…', false);
    var body, url;
    if (Store.mode === 'form') {
      body = JSON.stringify(Cmd.collect());
      url = '/api/preview-json';
    } else {
      body = document.getElementById('config').value;
      url = '/api/preview';
    }
    fetch(url, { method: 'POST', body: body }).then(function(r) { return r.json(); }).then(function(d) {
      if (d.ok) {
        document.getElementById('script').value = d.script;
        setStatus('预览完成：' + d.files + ' 个文件', false);
      } else {
        setStatus(d.message, true);
      }
    }).catch(function() { setStatus('预览失败', true); });
  },

  // ---- 保存 ----
  save: function() {
    var body, url;
    if (Store.mode === 'form') {
      body = JSON.stringify(Cmd.collect());
      url = '/api/config';
    } else {
      body = document.getElementById('config').value;
      url = '/api/save';
    }
    fetch(url, { method: 'POST', body: body }).then(function(r) { return r.json(); }).then(function(d) {
      setStatus(d.message, !d.ok);
      if (d.ok && Store.mode === 'form') Cmd.load();
    }).catch(function() { setStatus('保存失败', true); });
  },

  // ---- 分组操作 ----
  addGroup: function() {
    var cfg = Store.config || {};
    cfg.groupSettings = cfg.groupSettings || {};
    cfg.groupSettings.groups = cfg.groupSettings.groups || [];
    cfg.groupSettings.groups.push({ name: '', folder: '', enable: false });
    Store.config = cfg;
    UI.build();
  },
  // 原位切换分组启用状态（避免重建卡片丢失已输入内容）
  toggleGroup: function(i) {
    var groups = Store.config.groupSettings.groups;
    if (!groups || !groups[i]) return;
    groups[i].enable = !groups[i].enable;
    var card = document.querySelector('[data-group="' + i + '"]');
    if (!card) { UI.build(); return; }
    var on = groups[i].enable;
    card.classList.toggle('disabled', !on);
    var badge = card.querySelector('.badge');
    badge.className = 'badge' + (on ? ' on' : '');
    badge.textContent = on ? '已启用' : '未启用';
    var cb = card.querySelector('.g-enable input');
    cb.checked = on;
    var nm = card.querySelector('.ghead b');
    if (nm) nm.textContent = groups[i].name || ('分组 ' + (i + 1));
  },
  removeGroup: function(i) {
    var groups = Store.config.groupSettings.groups;
    if (groups) { groups.splice(i, 1); UI.build(); }
  },

  // ---- 预览面板显隐 ----
  togglePreview: function() {
    var hidden = document.body.classList.toggle('no-preview');
    document.getElementById('previewToggle').classList.toggle('active', !hidden);
    localStorage.setItem('scd.preview', hidden ? '0' : '1');
  },

  // ---- 预览视图切换：文本 / 图片 ----
  switchView: function(tab) {
    var isText = tab === 'text';
    document.getElementById('script').style.display = isText ? '' : 'none';
    // 必须显式 block：CSS 中 #imageWrap 默认 display:none，置 '' 会回落到样式表导致白屏
    document.getElementById('imageWrap').style.display = isText ? 'none' : 'block';
    document.querySelectorAll('.pv-btn[data-tab]').forEach(function(b) {
      b.classList.toggle('active', b.dataset.tab === tab);
    });
  },

  // ---- 生成图片（异步渲染任务：按启用 group 分多张 SVG，轮询进度）----
  renderImage: function() {
    setStatus('正在提交渲染任务…', false);
    showProgress(0, '提交渲染任务…');
    var body = Store.mode === 'form' ? JSON.stringify(Cmd.collect()) : document.getElementById('config').value;
    var autoGroup = document.getElementById('autoGroup').checked ? 1 : 0;
    var seq = (Cmd._renderSeq = (Cmd._renderSeq || 0) + 1);

    fetch('/api/render?autoGroup=' + autoGroup, { method: 'POST', body: body }).then(function(r) { return r.json(); }).then(function(d) {
      if (!d.ok) { hideProgress(); setStatus(d.message || '任务提交失败', true); return; }
      // 进度提示：共多少个类、多少张图
      updateProgress(0, '共 ' + d.types + ' 个类 · 共 ' + d.total + ' 张图，开始渲染…');
      pollRender(d.task, d.total, seq);
    }).catch(function() { hideProgress(); setStatus('任务提交失败', true); });

    function pollRender(id, total, seq) {
      if (seq !== Cmd._renderSeq) return; // 已发起新任务，放弃旧轮询
      fetch('/api/render/progress?task=' + encodeURIComponent(id)).then(function(r) { return r.json(); }).then(function(d) {
        if (seq !== Cmd._renderSeq) return;
        if (!d.ok) { hideProgress(); setStatus(d.message || '渲染失败', true); return; }
        if (!d.finished) {
          // 当前张记 15% 进度，其余按已完成张数均摊
          var pct = Math.round((d.done + 0.15) / d.total * 100);
          updateProgress(pct, d.phase + '（已完成 ' + d.done + '/' + d.total + '）');
          setTimeout(function() { pollRender(id, total, seq); }, 800);
        } else {
          if (d.error) { hideProgress(); setStatus('渲染失败：' + d.error, true); return; }
          hideProgress();
          renderImageCards(d.images || []);
          Cmd.switchView('image');
          setStatus('图片已生成：' + (d.images || []).length + ' 张', false);
        }
      }).catch(function() {
        // 网络抖动时继续轮询
        if (seq !== Cmd._renderSeq) return;
        setTimeout(function() { pollRender(id, total, seq); }, 1000);
      });
    }
  },

  // ---- 网页全屏（预览面板，Esc 退出）----
  toggleFullscreen: function() {
    var el = document.getElementById('rightPanel');
    if (document.fullscreenElement) {
      document.exitFullscreen();
    } else {
      var req = el.requestFullscreen || el.webkitRequestFullscreen;
      if (req) req.call(el);
    }
  }
};

/* ================================================================
   ImageCards：多图渲染（全部 + 每启用 group 一张）+ 缩放 + 拖动 + 全屏
   GoF 外观：统一管理图卡创建、缩放、全屏预览
   ================================================================ */

/* ---- 渲染进度条 ---- */
function showProgress(pct, text) {
  document.getElementById('renderProgress').style.display = 'block';
  updateProgress(pct, text);
}
function updateProgress(pct, text) {
  document.getElementById('rpFill').style.width = Math.max(2, Math.min(100, pct)) + '%';
  document.getElementById('rpText').textContent = text || '';
}
function hideProgress() {
  document.getElementById('renderProgress').style.display = 'none';
}

/* ---- Toast 提示（复制 / 保存结果）---- */
var toastTimer = null;
function showToast(text, isError) {
  var t = document.getElementById('toast');
  t.textContent = text;
  t.classList.toggle('err', !!isError);
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(function() { t.classList.remove('show'); }, 3000);
}

/* ---- 复制图片到剪贴板 ---- */
// SVG blob → PNG blob（剪贴板兼容性最好）：canvas 按 SVG 固有尺寸矢量绘制
function svgBlobToPng(blob, refImg) {
  return new Promise(function(resolve, reject) {
    var url = URL.createObjectURL(blob);
    var image = new Image();
    image.onload = function() {
      var w = image.naturalWidth || baseWidth(refImg);
      var ratio = refImg.naturalWidth > 0 && refImg.naturalHeight > 0 ? refImg.naturalHeight / refImg.naturalWidth : 0;
      var h = image.naturalHeight || (ratio > 0 ? Math.max(1, Math.round(w * ratio)) : w);
      var canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      canvas.getContext('2d').drawImage(image, 0, 0, w, h);
      URL.revokeObjectURL(url);
      canvas.toBlob(function(p) { p ? resolve(p) : reject(new Error('PNG 转换失败')); }, 'image/png');
    };
    image.onerror = function() { URL.revokeObjectURL(url); reject(new Error('图片加载失败')); };
    image.src = url;
  });
}

function copyImage(img, title) {
  fetch(img.src).then(function(r) { return r.blob(); }).then(function(blob) {
    if (!navigator.clipboard || !window.ClipboardItem) {
      showToast('当前浏览器不支持复制图片', true);
      return;
    }
    return svgBlobToPng(blob, img).then(function(pngBlob) {
      return navigator.clipboard.write([new ClipboardItem({ 'image/png': pngBlob })]);
    }).then(function() {
      showToast('已复制「' + title + '」图片到剪贴板');
    });
  }).catch(function(e) {
    showToast('复制失败：' + e.message, true);
  });
}

/* ---- 保存图片到本地 ---- */

// 生成保存文件名：group 名字 + 时间戳，如「Domain_20260809_153012.svg」。
// 剔除文件系统非法字符（\/:*?"<>|）与首尾空白，避免保存失败。
function buildSaveFileName(title) {
  var base = String(title || 'diagram').replace(/[\\/:*?"<>|\s]+/g, '_').replace(/^_+|_+$/g, '');
  if (!base) base = 'diagram';
  var d = new Date();
  function pad(n) { return n < 10 ? '0' + n : String(n); }
  var stamp = '' + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + '_' + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
  return base + '_' + stamp + '.svg';
}

function saveImage(img, title) {
  var fileName = buildSaveFileName(title);
  if (window.showSaveFilePicker) {
    // 在用户手势内先弹保存选择器，再异步写入（避免激活过期）
    window.showSaveFilePicker({
      suggestedName: fileName,
      types: [{ description: 'SVG 图片', accept: { 'image/svg+xml': ['.svg'] } }]
    }).then(function(handle) {
      return fetch(img.src).then(function(r) { return r.blob(); }).then(function(blob) {
        return handle.createWritable().then(function(w) { return w.write(blob).then(function() { return w.close(); }); });
      }).then(function() {
        showToast('已保存：' + (handle.name || fileName));
      });
    }).catch(function(e) {
      if (e && e.name === 'AbortError') return; // 用户取消选择
      showToast('保存失败：' + e.message, true);
    });
    return;
  }
  // 回退：浏览器直接下载到默认下载目录
  fetch(img.src).then(function(r) { return r.blob(); }).then(function(blob) {
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    setTimeout(function() { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    showToast('已开始下载：' + fileName + '（浏览器默认下载目录）');
  }).catch(function(e) {
    showToast('保存失败：' + e.message, true);
  });
}

// 绑定单张图卡的缩放 + 👋 拖动交互：
// 未选中 👋 → 滚轮缩放；选中 👋 → 光标变手掌、拖动平移、滚轮移动画面
// 已进入拖动模式的卡片退出回调集合：按 Esc 时统一取消选中（首页卡片）
var cardPanModes = [];

function bindCanvasInteractions(card, canvas, img, panBtn) {
  var panActive = false;
  panBtn.classList.remove('active');
  function setPan(active) {
    panActive = active;
    panBtn.classList.toggle('active', active);
    canvas.classList.toggle('pan-active', active);
    if (active) {
      canvas.scrollTop = 0;
      canvas.scrollLeft = 0;
      showToast('已进入拖动模式：按住左键拖动图片；再次点击 👋 或按 Esc 取消');
    }
  }
  panBtn.onclick = function() { setPan(!panActive); };
  // 注册取消回调，供全局 Esc 统一退出拖动模式
  cardPanModes.push(function() { if (panActive) setPan(false); });
  var panning = false, px = 0, py = 0, sx = 0, sy = 0, wrap = null;
  canvas.addEventListener('mousedown', function(e) {
    if (!panActive || e.button !== 0) return;
    // 首页卡片画布高度跟随图片（无内部纵向滚动），纵向滚动发生在外层 #imageWrap，
    // 因此同时记录画布横向位置与 #imageWrap 纵向位置。
    wrap = document.getElementById('imageWrap');
    panning = true; px = e.clientX; py = e.clientY;
    sx = canvas.scrollLeft; sy = wrap ? wrap.scrollTop : 0;
    canvas.classList.add('panning');
    e.preventDefault();
  });
  window.addEventListener('mousemove', function(e) {
    if (!panning) return;
    canvas.scrollLeft = sx - (e.clientX - px);
    if (wrap) wrap.scrollTop = sy - (e.clientY - py);
  });
  window.addEventListener('mouseup', function() {
    if (!panning) return;
    panning = false;
    canvas.classList.remove('panning');
  });
  canvas.addEventListener('wheel', function(e) {
    e.preventDefault();
    if (panActive) {
      // 拖动模式下滚轮平移：横向在画布内，纵向同步到外层 #imageWrap
      canvas.scrollLeft += e.deltaX;
      var w = document.getElementById('imageWrap');
      if (w) w.scrollTop += e.deltaY;
      return;
    }
    queueCardZoom(card, img, e.deltaY < 0 ? 1.1 : 0.9);
  }, { passive: false });
}

function base64ToBlob(b64) {
  var bin = atob(b64);
  var len = bin.length;
  var bytes = new Uint8Array(len);
  for (var i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
  // 后端输出矢量 SVG（仅 viewBox 无固有尺寸，naturalWidth 可能为 0，由 baseWidth 兜底）
  return new Blob([bytes], { type: 'image/svg+xml' });
}

// 缩放范围：最大 16 倍（大图放大到像素单元 ~16px、人眼可识别），最小可缩到 1%
function clampScale(s) { return Math.max(0.01, Math.min(16, Math.round(s * 100) / 100)); }

// SVG 无固有 width/height 时（仅 viewBox），naturalWidth 为 0，回退到默认基准宽度。
// 显示比例由 SVG viewBox 保证，img 的 CSS width 只决定渲染宽度，因此回退值不影响比例。
function baseWidth(img) { return (img.naturalWidth > 0) ? img.naturalWidth : 800; }

// 按 card.dataset.scale 渲染图片宽度（单一写入点，避免缩放时重复计算）
function applyCardScale(card, img) {
  var scale = clampScale(parseFloat(card.dataset.scale) || 1);
  img.style.width = Math.round(baseWidth(img) * scale) + 'px';
  card.querySelector('.ic-scale').textContent = Math.round(scale * 100) + '%';
}

// 设置单张图卡的缩放比例，img 宽度 = 基准宽度 × scale
function setCardScale(card, img, scale) {
  card.dataset.scale = String(clampScale(scale));
  applyCardScale(card, img);
}

// 滚轮缩放的帧合并：一帧内多次滚轮只重绘一次。
// 大图 SVG（viewBox 可达 12000px 宽）每次改宽都会重新光栅化，逐事件重绘会卡顿。
function queueCardZoom(card, img, factor) {
  card.dataset.scale = String(clampScale((parseFloat(card.dataset.scale) || 1) * factor));
  if (card._zoomRaf) return;
  card._zoomRaf = requestAnimationFrame(function() {
    card._zoomRaf = null;
    applyCardScale(card, img);
  });
}

// 适应画布宽度（不超过 100%）
function fitCardImage(card, img) {
  var canvas = card.querySelector('.ic-canvas');
  var avail = canvas.clientWidth - 20;
  setCardScale(card, img, Math.min(1, avail / baseWidth(img)));
}

// 渲染多张图卡
function renderImageCards(images) {
  var box = document.getElementById('imageBox');
  box.innerHTML = '';
  if (!images.length) {
    box.appendChild(UI.el('p', 'img-hint', '没有可渲染的图片'));
    return;
  }
  images.forEach(function(item) {
    var card = UI.el('div', 'img-card');
    card.dataset.title = item.title;

    var head = UI.el('div', 'ic-head');
    head.appendChild(UI.el('b', 'ic-title', item.title));
    var ops = UI.el('span', 'ic-ops');
    var pan = UI.el('button', 'pan-btn', '👋'); pan.title = '拖动模式：选中后拖动图片，滚轮平移';
    var zout = UI.el('button', null, '−'); zout.title = '缩小';
    var scaleEl = UI.el('span', 'ic-scale', '…');
    var zin = UI.el('button', null, '+'); zin.title = '放大';
    var fit = UI.el('button', null, '适应');
    var full = UI.el('button', null, '⛶'); full.title = '全屏预览';
    var copyBtn = UI.el('button', null, '复制'); copyBtn.title = '复制图片到剪贴板';
    var saveBtn = UI.el('button', null, '保存'); saveBtn.title = '保存图片到本地';
    [pan, zout, scaleEl, zin, fit, full, copyBtn, saveBtn].forEach(function(n) { ops.appendChild(n); });
    head.appendChild(ops);
    card.appendChild(head);

    if (item.error) {
      card.appendChild(UI.el('div', 'ic-error', '渲染失败（可能该 group 无匹配文件）'));
      box.appendChild(card);
      return;
    }

    var canvas = UI.el('div', 'ic-canvas');
    var img = UI.el('img');
    img.alt = item.title;
    img.src = URL.createObjectURL(base64ToBlob(item.data));
    canvas.appendChild(img);
    card.appendChild(canvas);
    box.appendChild(card);

    img.onload = function() {
      fitCardImage(card, img);
      zin.addEventListener('click', function() { setCardScale(card, img, parseFloat(card.dataset.scale || 1) * 1.25); });
      zout.addEventListener('click', function() { setCardScale(card, img, parseFloat(card.dataset.scale || 1) * 0.8); });
      fit.addEventListener('click', function() { fitCardImage(card, img); });
      full.addEventListener('click', function() { Lightbox.open(item.title, img.src); });
      copyBtn.addEventListener('click', function() { copyImage(img, item.title); });
      saveBtn.addEventListener('click', function() { saveImage(img, item.title); });
      bindCanvasInteractions(card, canvas, img, pan);
    };
  });
}

/* ---- 全屏预览（Lightbox）---- */
var Lightbox = {
  scale: 1,
  panActive: false,
  open: function(title, src) {
    this.scale = 1;
    this.panActive = false;
    document.getElementById('lbPan').classList.remove('active');
    document.getElementById('lbStage').classList.remove('pan-active');
    // 打开全屏预览时退出首页卡片的拖动模式，避免关闭后残留
    cardPanModes.forEach(function(off) { off(); });
    document.getElementById('lbTitle').textContent = title;
    var img = document.getElementById('lbImg');
    img.src = src;
    document.getElementById('lbScale').textContent = '100%';
    document.getElementById('lightbox').classList.remove('lb-hidden');
    img.onload = function() { Lightbox.fit(); };
  },
  close: function() {
    document.getElementById('lightbox').classList.add('lb-hidden');
    // 关闭时退出拖动模式，避免下次打开残留
    this.panActive = false;
    document.getElementById('lbPan').classList.remove('active');
    document.getElementById('lbStage').classList.remove('pan-active');
  },
  apply: function() {
    var img = document.getElementById('lbImg');
    this.scale = clampScale(this.scale);
    img.style.width = Math.round(baseWidth(img) * this.scale) + 'px';
    document.getElementById('lbScale').textContent = Math.round(this.scale * 100) + '%';
  },
  zoom: function(dir) {
    this.scale *= dir > 0 ? 1.25 : 0.8;
    // 与首页一致：滚轮缩放按帧合并，一帧内多次调用只重绘一次，避免大 SVG 反复光栅化卡顿
    if (this._zoomRaf) return;
    var self = this;
    this._zoomRaf = requestAnimationFrame(function() {
      self._zoomRaf = null;
      self.apply();
    });
  },
  fit: function() {
    var img = document.getElementById('lbImg');
    var stage = document.getElementById('lbStage');
    this.scale = Math.min(1, (stage.clientWidth - 32) / baseWidth(img));
    this.apply();
  }
};

// ---- View 读取控件值 ----
UI.readControl = function(el) {
  if (el.classList.contains('tag-input')) {
    var vals = [];
    el.querySelectorAll('.tag').forEach(function(t) { vals.push(t.dataset.value); });
    var ed = el.querySelector('.tag-editor');
    if (ed && ed.value.trim()) vals.push(ed.value.trim());
    return vals;
  }
  if (el.classList.contains('tri')) {
    if (el.value === '') return undefined;
    return el.value === 'true';
  }
  if (el.type === 'checkbox') return el.checked;
  if (el.tagName === 'SELECT') return el.value === '' ? undefined : el.value;
  if (el.classList.contains('str-array')) {
    return el.value.split(/[,\n]+/).map(function(s) { return s.trim(); }).filter(Boolean);
  }
  if (el.classList.contains('line-array')) {
    return el.value.split('\n').map(function(s) { return s.trim(); }).filter(Boolean);
  }
  if (el.type === 'text') {
    var s = el.value.trim();
    return s === '' ? undefined : s;
  }
  return el.value;
};

// ---- 路径写入（支持 a[0].b 语法）----
function setAtPath(obj, path, value) {
  var parts = path.split('.');
  var cur = obj;
  for (var i = 0; i < parts.length - 1; i++) {
    var part = parts[i];
    var m = part.match(/^(\w+)\[(\d+)\]$/);
    if (m) {
      var arr = cur[m[1]] || (cur[m[1]] = []);
      var idx = parseInt(m[2], 10);
      cur = arr[idx] || (arr[idx] = {});
    } else {
      var next = cur[part];
      if (typeof next !== 'object' || next === null) cur = cur[part] = {};
      else cur = next;
    }
  }
  var last = parts[parts.length - 1];
  var lm = last.match(/^(\w+)\[(\d+)\]$/);
  if (lm) {
    var a2 = cur[lm[1]] || (cur[lm[1]] = []);
    a2[parseInt(lm[2], 10)] = value;
  } else {
    cur[last] = value;
  }
}

// ---- 空值清理 ----
function cleanup(obj) {
  if (Array.isArray(obj)) {
    var a = obj.filter(function(x) { return x !== undefined && x !== null && x !== ''; }).map(cleanup)
      .filter(function(x) { return !(typeof x === 'object' && x !== null && Object.keys(x).length === 0); });
    return a.length ? a : undefined;
  }
  if (typeof obj === 'object' && obj !== null) {
    var out = {};
    Object.keys(obj).forEach(function(k) {
      var v = cleanup(obj[k]);
      if (v === undefined || v === null || v === '') return;
      if (typeof v === 'object' && Object.keys(v).length === 0) return;
      out[k] = v;
    });
    return out;
  }
  return obj;
}

function fillDirList(dirs) {
  var dl = document.getElementById('dir-list');
  if (!dl) {
    dl = UI.el('datalist');
    dl.id = 'dir-list';
    document.body.appendChild(dl);
  }
  dl.innerHTML = '';
  dirs.forEach(function(d) {
    var o = UI.el('option');
    o.value = d;
    dl.appendChild(o);
  });
}

function setStatus(msg, isError) {
  var el = document.getElementById('status');
  el.textContent = msg;
  el.className = isError ? 'error' : 'ok';
}

/* ================================================================
   Resizer：左右拖拽调整编辑器宽度（双击复位）
   ================================================================ */
function initResizer() {
  var resizer = document.getElementById('resizer');
  var left = document.getElementById('leftPanel');
  var startX = 0, startW = 0, dragging = false;

  resizer.addEventListener('mousedown', function(e) {
    dragging = true;
    startX = e.clientX;
    startW = left.offsetWidth;
    document.body.classList.add('resizing');
    e.preventDefault();
  });
  document.addEventListener('mousemove', function(e) {
    if (!dragging) return;
    var w = Math.min(Math.max(startW + e.clientX - startX, 260), window.innerWidth * 0.6);
    left.style.width = w + 'px';
  });
  document.addEventListener('mouseup', function() {
    if (!dragging) return;
    dragging = false;
    document.body.classList.remove('resizing');
    localStorage.setItem('scd.leftWidth', left.style.width);
  });
  resizer.addEventListener('dblclick', function() {
    left.style.width = '420px';
    localStorage.setItem('scd.leftWidth', '420px');
  });

  var saved = localStorage.getItem('scd.leftWidth');
  if (saved) left.style.width = saved;
}

// ---- 初始化 ----
(function init() {
  initResizer();
  var savedPreview = localStorage.getItem('scd.preview');
  if (savedPreview === '0') {
    document.body.classList.add('no-preview');
    document.getElementById('previewToggle').classList.remove('active');
  }
  // 全屏预览控件
  document.getElementById('lbClose').addEventListener('click', function() { Lightbox.close(); });
  document.getElementById('lbZoomIn').addEventListener('click', function() { Lightbox.zoom(1); });
  document.getElementById('lbZoomOut').addEventListener('click', function() { Lightbox.zoom(-1); });
  document.getElementById('lbFit').addEventListener('click', function() { Lightbox.fit(); });
  document.getElementById('lbStage').addEventListener('click', function(e) { if (e.target === this) Lightbox.close(); });

  // Lightbox 复制/保存：以当前预览图片为准
  document.getElementById('lbCopy').addEventListener('click', function() {
    copyImage(document.getElementById('lbImg'), document.getElementById('lbTitle').textContent);
  });
  document.getElementById('lbSave').addEventListener('click', function() {
    saveImage(document.getElementById('lbImg'), document.getElementById('lbTitle').textContent);
  });

  // Lightbox 👋 拖动模式：选中后光标变手掌、拖动平移、滚轮平移；取消后滚轮缩放
  var lbStage = document.getElementById('lbStage');
  document.getElementById('lbPan').addEventListener('click', function() {
    Lightbox.panActive = !Lightbox.panActive;
    this.classList.toggle('active', Lightbox.panActive);
    lbStage.classList.toggle('pan-active', Lightbox.panActive);
    if (Lightbox.panActive) {
      lbStage.scrollTop = 0;
      lbStage.scrollLeft = 0;
      showToast('已进入拖动模式：按住左键拖动图片；再次点击 👋 或按 Esc 取消');
    }
  });
  (function() {
    var panning = false, px = 0, py = 0, sx = 0, sy = 0;
    lbStage.addEventListener('mousedown', function(e) {
      if (!Lightbox.panActive || e.button !== 0) return;
      panning = true; px = e.clientX; py = e.clientY;
      sx = lbStage.scrollLeft; sy = lbStage.scrollTop;
      lbStage.classList.add('panning');
      e.preventDefault();
    });
    window.addEventListener('mousemove', function(e) {
      if (!panning) return;
      lbStage.scrollLeft = sx - (e.clientX - px);
      lbStage.scrollTop = sy - (e.clientY - py);
    });
    window.addEventListener('mouseup', function() {
      if (!panning) return;
      panning = false;
      lbStage.classList.remove('panning');
    });
  })();
  lbStage.addEventListener('wheel', function(e) {
    e.preventDefault();
    if (Lightbox.panActive) {
      lbStage.scrollTop += e.deltaY;
      lbStage.scrollLeft += e.deltaX;
      return;
    }
    Lightbox.zoom(e.deltaY < 0 ? 1 : -1);
  }, { passive: false });

  // 网页全屏状态：按钮文案随全屏状态切换
  document.addEventListener('fullscreenchange', function() {
    var btn = document.getElementById('fsBtn');
    if (btn) btn.textContent = document.fullscreenElement ? '退出全屏' : '全屏';
  });
  Cmd.load();
})();
