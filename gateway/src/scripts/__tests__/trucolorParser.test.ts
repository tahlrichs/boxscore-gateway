import { parseTrucolorPage } from '../trucolorParser';

// --- Fixture HTML fragments ---

const PRO_HTML = `
<div class="collapseomatic" id="team1"
  title="&#9989; <strong>ATLANTA HAWKS</strong> (1968-1969 through present)">
  <strong>ATLANTA HAWKS</strong>
</div>
<div class="collapseomatic_content">
  <div class="collapseomatic" id="era1"
    title="2020-2021 through present: <strong>Torch Red, Volt Green, White</strong>">
  </div>
  <div class="collapseomatic_content">
    <div class="acb-box" style="background-color: #C8102E; width:50px; height:50px;"></div>
    <div class="acb-box" style="background-color: #C1D32F; width:50px; height:50px;"></div>
    <div class="acb-box" style="background-color: #FFFFFF; width:50px; height:50px;"></div>
  </div>
</div>

<div class="collapseomatic" id="team2"
  title="<strong>BOSTON CELTICS</strong> (1946-1947 through present)">
  <strong>BOSTON CELTICS</strong>
</div>
<div class="collapseomatic_content">
  <div class="collapseomatic" id="era2"
    title="2014-2015 through present: <strong>Green, Gold, White</strong>">
  </div>
  <div class="collapseomatic_content">
    <div class="acb-box" style="background-color: #007A33; width:50px; height:50px;"></div>
    <div class="acb-box" style="background-color: #BA9653; width:50px; height:50px;"></div>
  </div>
</div>
`;

const NCAA_HTML = `
<div class="collapseomatic " id="school1"
  title="UNIVERSITY OF ALABAMA">
  <strong>UNIVERSITY OF ALABAMA</strong>
</div>
<div class="collapseomatic_content">
  <div class="collapseomatic" title="ATHLETICS COLORS">ATHLETICS COLORS</div>
  <div class="collapseomatic_content">
    <div class="collapseomatic" id="era-a1"
      title="2015 through present: <strong>Crimson, White</strong>">
    </div>
    <div class="collapseomatic_content">
      <div class="acb-box" style="background-color: #9E1B32; width:50px; height:50px;"></div>
      <div class="acb-box" style="background-color: #FFFFFF; width:50px; height:50px;"></div>
    </div>
  </div>
</div>

<div class="collapseomatic " id="school2"
  title="AUBURN UNIVERSITY">
  <strong>AUBURN UNIVERSITY</strong>
</div>
<div class="collapseomatic_content">
  <div class="collapseomatic" title="ATHLETICS COLORS">ATHLETICS COLORS</div>
  <div class="collapseomatic_content">
    <div class="collapseomatic" id="era-a2"
      title="2004 through present: <strong>Burnt Orange, Navy Blue</strong>">
    </div>
    <div class="collapseomatic_content">
      <div class="acb-box" style="background-color: #DD550C; width:50px; height:50px;"></div>
      <div class="acb-box" style="background-color: #03244D; width:50px; height:50px;"></div>
    </div>
  </div>
</div>
`;

// --- Tests ---

describe('parseTrucolorPage (pro)', () => {
  const abbrevMap: Record<string, string> = {
    'ATLANTA HAWKS': 'atl',
    'BOSTON CELTICS': 'bos',
  };

  it('extracts teams with checkmark emoji', () => {
    const result = parseTrucolorPage(PRO_HTML, abbrevMap);
    expect(result.teams.atl).toBeDefined();
    expect(result.teams.atl.primary).toBe('#C8102E');
    expect(result.teams.atl.secondary).toBe('#C1D32F');
  });

  it('extracts teams without checkmark emoji', () => {
    const result = parseTrucolorPage(PRO_HTML, abbrevMap);
    expect(result.teams.bos).toBeDefined();
    expect(result.teams.bos.primary).toBe('#007A33');
    expect(result.teams.bos.secondary).toBe('#BA9653');
  });

  it('title-cases team names', () => {
    const result = parseTrucolorPage(PRO_HTML, abbrevMap);
    expect(result.teams.atl.name).toBe('Atlanta Hawks');
    expect(result.teams.bos.name).toBe('Boston Celtics');
  });

  it('reports unmapped teams', () => {
    const result = parseTrucolorPage(PRO_HTML, { 'ATLANTA HAWKS': 'atl' });
    expect(result.unmapped).toContain('BOSTON CELTICS');
  });

  it('returns empty for HTML with no matching teams', () => {
    const result = parseTrucolorPage('<html><body>nothing</body></html>', abbrevMap);
    expect(Object.keys(result.teams)).toHaveLength(0);
    expect(result.unmapped).toHaveLength(0);
  });
});

describe('parseTrucolorPage (ncaa)', () => {
  const abbrevMap: Record<string, string> = {
    'UNIVERSITY OF ALABAMA': 'alabama',
    'AUBURN UNIVERSITY': 'auburn',
  };

  it('extracts NCAA schools from ATHLETICS COLORS sections', () => {
    const result = parseTrucolorPage(NCAA_HTML, abbrevMap, true);
    expect(result.teams.alabama).toBeDefined();
    expect(result.teams.alabama.primary).toBe('#9E1B32');
    expect(result.teams.auburn).toBeDefined();
    expect(result.teams.auburn.primary).toBe('#DD550C');
    expect(result.teams.auburn.secondary).toBe('#03244D');
  });

  it('ignores subsection headers like year eras', () => {
    const htmlWithSubsections = `
      <div class="collapseomatic " title="2015 through present">2015</div>
      <div class="collapseomatic " title="ATHLETICS COLORS">ATHLETICS COLORS</div>
      <div class="collapseomatic " title="UNIVERSITY OF ALABAMA">
        <strong>UNIVERSITY OF ALABAMA</strong>
      </div>
      <div class="collapseomatic_content">
        <div class="collapseomatic" title="ATHLETICS COLORS">ATHLETICS COLORS</div>
        <div class="collapseomatic_content">
          <div class="collapseomatic" title="2020 through present: <strong>Crimson</strong>"></div>
          <div class="collapseomatic_content">
            <div class="acb-box" style="background-color: #9E1B32;"></div>
          </div>
        </div>
      </div>
    `;
    const result = parseTrucolorPage(htmlWithSubsections, abbrevMap, true);
    // Should only match the school, not the year or ATHLETICS COLORS headers
    expect(Object.keys(result.teams)).toHaveLength(1);
    expect(result.teams.alabama).toBeDefined();
  });

  it('handles shorthand hex codes', () => {
    const html = `
      <div class="collapseomatic " title="TEST UNIVERSITY"><strong>TEST UNIVERSITY</strong></div>
      <div class="collapseomatic_content">
        <div class="acb-box" style="background-color: #F00;"></div>
        <div class="acb-box" style="background-color: #0F0;"></div>
      </div>
    `;
    const result = parseTrucolorPage(html, { 'TEST UNIVERSITY': 'test' }, true);
    expect(result.teams.test.primary).toBe('#FF0000');
    expect(result.teams.test.secondary).toBe('#00FF00');
  });
});
