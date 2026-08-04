// fast-diff@1.3.0 downloaded from https://ga.jspm.io/npm:fast-diff@1.3.0/diff.js

var r={};var e=-1;var i=1;var t=0;
/**
 * Find the differences between two texts.  Simplifies the problem by stripping
 * any common prefix or suffix off the texts before diffing.
 * @param {string} text1 Old string to be diffed.
 * @param {string} text2 New string to be diffed.
 * @param {Int|Object} [cursor_pos] Edit position in text1 or object with more info
 * @param {boolean} [cleanup] Apply semantic cleanup before returning.
 * @return {Array} Array of diff tuples.
 */function diff_main(r,e,i,n,a){if(r===e)return r?[[t,r]]:[];if(null!=i){var l=find_cursor_edit_diff(r,e,i);if(l)return l}var f=diff_commonPrefix(r,e);var s=r.substring(0,f);r=r.substring(f);e=e.substring(f);f=diff_commonSuffix(r,e);var h=r.substring(r.length-f);r=r.substring(0,r.length-f);e=e.substring(0,e.length-f);var u=diff_compute_(r,e);s&&u.unshift([t,s]);h&&u.push([t,h]);diff_cleanupMerge(u,a);n&&diff_cleanupSemantic(u);return u}
/**
 * Find the differences between two texts.  Assumes that the texts do not
 * have any common prefix or suffix.
 * @param {string} text1 Old string to be diffed.
 * @param {string} text2 New string to be diffed.
 * @return {Array} Array of diff tuples.
 */function diff_compute_(r,n){var a;if(!r)return[[i,n]];if(!n)return[[e,r]];var l=r.length>n.length?r:n;var f=r.length>n.length?n:r;var s=l.indexOf(f);if(-1!==s){a=[[i,l.substring(0,s)],[t,f],[i,l.substring(s+f.length)]];r.length>n.length&&(a[0][0]=a[2][0]=e);return a}if(1===f.length)return[[e,r],[i,n]];var h=diff_halfMatch_(r,n);if(h){var u=h[0];var g=h[1];var v=h[2];var c=h[3];var _=h[4];var o=diff_main(u,v);var d=diff_main(g,c);return o.concat([[t,_]],d)}return diff_bisect_(r,n)}
/**
 * Find the 'middle snake' of a diff, split the problem in two
 * and return the recursively constructed diff.
 * See Myers 1986 paper: An O(ND) Difference Algorithm and Its Variations.
 * @param {string} text1 Old string to be diffed.
 * @param {string} text2 New string to be diffed.
 * @return {Array} Array of diff tuples.
 * @private
 */function diff_bisect_(r,t){var n=r.length;var a=t.length;var l=Math.ceil((n+a)/2);var f=l;var s=2*l;var h=new Array(s);var u=new Array(s);for(var g=0;g<s;g++){h[g]=-1;u[g]=-1}h[f+1]=0;u[f+1]=0;var v=n-a;var c=v%2!==0;var _=0;var o=0;var d=0;var m=0;for(var b=0;b<l;b++){for(var p=-b+_;p<=b-o;p+=2){var S=f+p;y=p===-b||p!==b&&h[S-1]<h[S+1]?h[S+1]:h[S-1]+1;var w=y-p;while(y<n&&w<a&&r.charAt(y)===t.charAt(w)){y++;w++}h[S]=y;if(y>n)o+=2;else if(w>a)_+=2;else if(c){var M=f+v-p;if(M>=0&&M<s&&-1!==u[M]){var A=n-u[M];if(y>=A)return diff_bisectSplit_(r,t,y,w)}}}for(var x=-b+d;x<=b-m;x+=2){M=f+x;A=x===-b||x!==b&&u[M-1]<u[M+1]?u[M+1]:u[M-1]+1;var k=A-x;while(A<n&&k<a&&r.charAt(n-A-1)===t.charAt(a-k-1)){A++;k++}u[M]=A;if(A>n)m+=2;else if(k>a)d+=2;else if(!c){S=f+v-x;if(S>=0&&S<s&&-1!==h[S]){var y=h[S];w=f+y-S;A=n-A;if(y>=A)return diff_bisectSplit_(r,t,y,w)}}}}return[[e,r],[i,t]]}
/**
 * Given the location of the 'middle snake', split the diff in two parts
 * and recurse.
 * @param {string} text1 Old string to be diffed.
 * @param {string} text2 New string to be diffed.
 * @param {number} x Index of split point in text1.
 * @param {number} y Index of split point in text2.
 * @return {Array} Array of diff tuples.
 */function diff_bisectSplit_(r,e,i,t){var n=r.substring(0,i);var a=e.substring(0,t);var l=r.substring(i);var f=e.substring(t);var s=diff_main(n,a);var h=diff_main(l,f);return s.concat(h)}
/**
 * Determine the common prefix of two strings.
 * @param {string} text1 First string.
 * @param {string} text2 Second string.
 * @return {number} The number of characters common to the start of each
 *     string.
 */function diff_commonPrefix(r,e){if(!r||!e||r.charAt(0)!==e.charAt(0))return 0;var i=0;var t=Math.min(r.length,e.length);var n=t;var a=0;while(i<n){if(r.substring(a,n)==e.substring(a,n)){i=n;a=i}else t=n;n=Math.floor((t-i)/2+i)}is_surrogate_pair_start(r.charCodeAt(n-1))&&n--;return n}
/**
 * Determine if the suffix of one string is the prefix of another.
 * @param {string} text1 First string.
 * @param {string} text2 Second string.
 * @return {number} The number of characters common to the end of the first
 *     string and the start of the second string.
 * @private
 */function diff_commonOverlap_(r,e){var i=r.length;var t=e.length;if(0==i||0==t)return 0;i>t?r=r.substring(i-t):i<t&&(e=e.substring(0,i));var n=Math.min(i,t);if(r==e)return n;var a=0;var l=1;while(true){var f=r.substring(n-l);var s=e.indexOf(f);if(-1==s)return a;l+=s;if(0==s||r.substring(n-l)==e.substring(0,l)){a=l;l++}}}
/**
 * Determine the common suffix of two strings.
 * @param {string} text1 First string.
 * @param {string} text2 Second string.
 * @return {number} The number of characters common to the end of each string.
 */function diff_commonSuffix(r,e){if(!r||!e||r.slice(-1)!==e.slice(-1))return 0;var i=0;var t=Math.min(r.length,e.length);var n=t;var a=0;while(i<n){if(r.substring(r.length-n,r.length-a)==e.substring(e.length-n,e.length-a)){i=n;a=i}else t=n;n=Math.floor((t-i)/2+i)}is_surrogate_pair_end(r.charCodeAt(r.length-n))&&n--;return n}
/**
 * Do the two texts share a substring which is at least half the length of the
 * longer text?
 * This speedup can produce non-minimal diffs.
 * @param {string} text1 First string.
 * @param {string} text2 Second string.
 * @return {Array.<string>} Five element Array, containing the prefix of
 *     text1, the suffix of text1, the prefix of text2, the suffix of
 *     text2 and the common middle.  Or null if there was no match.
 */function diff_halfMatch_(r,e){var i=r.length>e.length?r:e;var t=r.length>e.length?e:r;if(i.length<4||2*t.length<i.length)return null;
/**
   * Does a substring of shorttext exist within longtext such that the substring
   * is at least half the length of longtext?
   * Closure, but does not reference any external variables.
   * @param {string} longtext Longer string.
   * @param {string} shorttext Shorter string.
   * @param {number} i Start index of quarter length substring within longtext.
   * @return {Array.<string>} Five element Array, containing the prefix of
   *     longtext, the suffix of longtext, the prefix of shorttext, the suffix
   *     of shorttext and the common middle.  Or null if there was no match.
   * @private
   */function diff_halfMatchI_(r,e,i){var t=r.substring(i,i+Math.floor(r.length/4));var n=-1;var a="";var l,f,s,h;while(-1!==(n=e.indexOf(t,n+1))){var u=diff_commonPrefix(r.substring(i),e.substring(n));var g=diff_commonSuffix(r.substring(0,i),e.substring(0,n));if(a.length<g+u){a=e.substring(n-g,n)+e.substring(n,n+u);l=r.substring(0,i-g);f=r.substring(i+u);s=e.substring(0,n-g);h=e.substring(n+u)}}return 2*a.length>=r.length?[l,f,s,h,a]:null}var n=diff_halfMatchI_(i,t,Math.ceil(i.length/4));var a=diff_halfMatchI_(i,t,Math.ceil(i.length/2));var l;if(!n&&!a)return null;l=a?n&&n[4].length>a[4].length?n:a:n;var f,s,h,u;if(r.length>e.length){f=l[0];s=l[1];h=l[2];u=l[3]}else{h=l[0];u=l[1];f=l[2];s=l[3]}var g=l[4];return[f,s,h,u,g]}
/**
 * Reduce the number of edits by eliminating semantically trivial equalities.
 * @param {!Array.<!diff_match_patch.Diff>} diffs Array of diff tuples.
 */function diff_cleanupSemantic(r){var n=false;var a=[];var l=0;
/** @type {?string} */var f=null;var s=0;var h=0;var u=0;var g=0;var v=0;while(s<r.length){if(r[s][0]==t){a[l++]=s;h=g;u=v;g=0;v=0;f=r[s][1]}else{r[s][0]==i?g+=r[s][1].length:v+=r[s][1].length;if(f&&f.length<=Math.max(h,u)&&f.length<=Math.max(g,v)){r.splice(a[l-1],0,[e,f]);r[a[l-1]+1][0]=i;l--;l--;s=l>0?a[l-1]:-1;h=0;u=0;g=0;v=0;f=null;n=true}}s++}n&&diff_cleanupMerge(r);diff_cleanupSemanticLossless(r);s=1;while(s<r.length){if(r[s-1][0]==e&&r[s][0]==i){var c=r[s-1][1];var _=r[s][1];var o=diff_commonOverlap_(c,_);var d=diff_commonOverlap_(_,c);if(o>=d){if(o>=c.length/2||o>=_.length/2){r.splice(s,0,[t,_.substring(0,o)]);r[s-1][1]=c.substring(0,c.length-o);r[s+1][1]=_.substring(o);s++}}else if(d>=c.length/2||d>=_.length/2){r.splice(s,0,[t,c.substring(0,d)]);r[s-1][0]=i;r[s-1][1]=_.substring(0,_.length-d);r[s+1][0]=e;r[s+1][1]=c.substring(d);s++}s++}s++}}var n=/[^a-zA-Z0-9]/;var a=/\s/;var l=/[\r\n]/;var f=/\n\r?\n$/;var s=/^\r?\n\r?\n/;
/**
 * Look for single edits surrounded on both sides by equalities
 * which can be shifted sideways to align the edit to a word boundary.
 * e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
 * @param {!Array.<!diff_match_patch.Diff>} diffs Array of diff tuples.
 */function diff_cleanupSemanticLossless(r){
/**
   * Given two strings, compute a score representing whether the internal
   * boundary falls on logical boundaries.
   * Scores range from 6 (best) to 0 (worst).
   * Closure, but does not reference any external variables.
   * @param {string} one First string.
   * @param {string} two Second string.
   * @return {number} The score.
   * @private
   */
function diff_cleanupSemanticScore_(r,e){if(!r||!e)return 6;var i=r.charAt(r.length-1);var t=e.charAt(0);var h=i.match(n);var u=t.match(n);var g=h&&i.match(a);var v=u&&t.match(a);var c=g&&i.match(l);var _=v&&t.match(l);var o=c&&r.match(f);var d=_&&e.match(s);return o||d?5:c||_?4:h&&!g&&v?3:g||v?2:h||u?1:0}var e=1;while(e<r.length-1){if(r[e-1][0]==t&&r[e+1][0]==t){var i=r[e-1][1];var h=r[e][1];var u=r[e+1][1];var g=diff_commonSuffix(i,h);if(g){var v=h.substring(h.length-g);i=i.substring(0,i.length-g);h=v+h.substring(0,h.length-g);u=v+u}var c=i;var _=h;var o=u;var d=diff_cleanupSemanticScore_(i,h)+diff_cleanupSemanticScore_(h,u);while(h.charAt(0)===u.charAt(0)){i+=h.charAt(0);h=h.substring(1)+u.charAt(0);u=u.substring(1);var m=diff_cleanupSemanticScore_(i,h)+diff_cleanupSemanticScore_(h,u);if(m>=d){d=m;c=i;_=h;o=u}}if(r[e-1][1]!=c){if(c)r[e-1][1]=c;else{r.splice(e-1,1);e--}r[e][1]=_;if(o)r[e+1][1]=o;else{r.splice(e+1,1);e--}}}e++}}
/**
 * Reorder and merge like edit sections.  Merge equalities.
 * Any edit section can move as long as it doesn't cross an equality.
 * @param {Array} diffs Array of diff tuples.
 * @param {boolean} fix_unicode Whether to normalize to a unicode-correct diff
 */function diff_cleanupMerge(r,n){r.push([t,""]);var a=0;var l=0;var f=0;var s="";var h="";var u;while(a<r.length)if(a<r.length-1&&!r[a][1])r.splice(a,1);else switch(r[a][0]){case i:f++;h+=r[a][1];a++;break;case e:l++;s+=r[a][1];a++;break;case t:var g=a-f-l-1;if(n){if(g>=0&&ends_with_pair_start(r[g][1])){var v=r[g][1].slice(-1);r[g][1]=r[g][1].slice(0,-1);s=v+s;h=v+h;if(!r[g][1]){r.splice(g,1);a--;var c=g-1;if(r[c]&&r[c][0]===i){f++;h=r[c][1]+h;c--}if(r[c]&&r[c][0]===e){l++;s=r[c][1]+s;c--}g=c}}if(starts_with_pair_end(r[a][1])){v=r[a][1].charAt(0);r[a][1]=r[a][1].slice(1);s+=v;h+=v}}if(a<r.length-1&&!r[a][1]){r.splice(a,1);break}if(s.length>0||h.length>0){if(s.length>0&&h.length>0){u=diff_commonPrefix(h,s);if(0!==u){if(g>=0)r[g][1]+=h.substring(0,u);else{r.splice(0,0,[t,h.substring(0,u)]);a++}h=h.substring(u);s=s.substring(u)}u=diff_commonSuffix(h,s);if(0!==u){r[a][1]=h.substring(h.length-u)+r[a][1];h=h.substring(0,h.length-u);s=s.substring(0,s.length-u)}}var _=f+l;if(0===s.length&&0===h.length){r.splice(a-_,_);a-=_}else if(0===s.length){r.splice(a-_,_,[i,h]);a=a-_+1}else if(0===h.length){r.splice(a-_,_,[e,s]);a=a-_+1}else{r.splice(a-_,_,[e,s],[i,h]);a=a-_+2}}if(0!==a&&r[a-1][0]===t){r[a-1][1]+=r[a][1];r.splice(a,1)}else a++;f=0;l=0;s="";h="";break}""===r[r.length-1][1]&&r.pop();var o=false;a=1;while(a<r.length-1){if(r[a-1][0]===t&&r[a+1][0]===t)if(r[a][1].substring(r[a][1].length-r[a-1][1].length)===r[a-1][1]){r[a][1]=r[a-1][1]+r[a][1].substring(0,r[a][1].length-r[a-1][1].length);r[a+1][1]=r[a-1][1]+r[a+1][1];r.splice(a-1,1);o=true}else if(r[a][1].substring(0,r[a+1][1].length)==r[a+1][1]){r[a-1][1]+=r[a+1][1];r[a][1]=r[a][1].substring(r[a+1][1].length)+r[a+1][1];r.splice(a+1,1);o=true}a++}o&&diff_cleanupMerge(r,n)}function is_surrogate_pair_start(r){return r>=55296&&r<=56319}function is_surrogate_pair_end(r){return r>=56320&&r<=57343}function starts_with_pair_end(r){return is_surrogate_pair_end(r.charCodeAt(0))}function ends_with_pair_start(r){return is_surrogate_pair_start(r.charCodeAt(r.length-1))}function remove_empty_tuples(r){var e=[];for(var i=0;i<r.length;i++)r[i][1].length>0&&e.push(r[i]);return e}function make_edit_splice(r,n,a,l){return ends_with_pair_start(r)||starts_with_pair_end(l)?null:remove_empty_tuples([[t,r],[e,n],[i,a],[t,l]])}function find_cursor_edit_diff(r,e,i){var t="number"===typeof i?{index:i,length:0}:i.oldRange;var n="number"===typeof i?null:i.newRange;var a=r.length;var l=e.length;if(0===t.length&&(null===n||0===n.length)){var f=t.index;var s=r.slice(0,f);var h=r.slice(f);var u=n?n.index:null;var g=f+l-a;if((null===u||u===g)&&!(g<0||g>l)){var v=e.slice(0,g);var c=e.slice(g);if(c===h){var _=Math.min(f,g);var o=s.slice(0,_);var d=v.slice(0,_);if(o===d){var m=s.slice(_);var b=v.slice(_);return make_edit_splice(o,m,b,h)}}}if(null===u||u===f){var p=f;v=e.slice(0,p);c=e.slice(p);if(v===s){var S=Math.min(a-p,l-p);var w=h.slice(h.length-S);var M=c.slice(c.length-S);if(w===M){m=h.slice(0,h.length-S);b=c.slice(0,c.length-S);return make_edit_splice(s,m,b,w)}}}}if(t.length>0&&n&&0===n.length){o=r.slice(0,t.index);w=r.slice(t.index+t.length);_=o.length;S=w.length;if(!(l<_+S)){d=e.slice(0,_);M=e.slice(l-S);if(o===d&&w===M){m=r.slice(_,a-S);b=e.slice(_,l-S);return make_edit_splice(o,m,b,w)}}}return null}function diff(r,e,i,t){return diff_main(r,e,i,t,true)}diff.INSERT=i;diff.DELETE=e;diff.EQUAL=t;r=diff;var h=r;export{h as default};

