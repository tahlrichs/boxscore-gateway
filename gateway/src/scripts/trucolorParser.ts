/**
 * Pure HTML parser for TruColor.net team color pages.
 * No network calls — takes HTML string in, returns parsed colors out.
 *
 * Handles two page formats:
 *   Pro leagues: title="&#9989; <strong>TEAM NAME</strong> (year through present)"
 *   NCAA:        title="SCHOOL NAME" with nested "ATHLETICS COLORS" sections
 */

export interface TeamColors {
  primary: string;
  secondary: string;
  name: string;
}

export interface ParseResult {
  teams: Record<string, TeamColors>;
  unmapped: string[];
}

const HEX_REGEX = /^#[0-9A-Fa-f]{6}$/;

/**
 * Parse a TruColor pro-league page (NBA/NFL/NHL/MLB).
 * Teams are marked with &#9989; checkmark emoji.
 */
export function parseTrucolorPage(
  html: string,
  abbrevMap: Record<string, string>,
  isNcaa: boolean = false,
): ParseResult {
  if (isNcaa) {
    return parseNcaaPage(html, abbrevMap);
  }
  return parseProPage(html, abbrevMap);
}

function parseProPage(html: string, abbrevMap: Record<string, string>): ParseResult {
  const teams: Record<string, TeamColors> = {};
  const unmapped: string[] = [];

  // Pro team headers come in two forms:
  //   1. title="&#9989; <strong>TEAM NAME</strong> (year through present)"  (with checkmark)
  //   2. title="<strong>TEAM NAME</strong> (year through present)"          (without checkmark)
  // Both indicate current teams due to "through present". We match both.
  const teamPattern = /title="(?:&#9989;|✅)?\s*<strong>([^<]+)<\/strong>\s*\([^)]*through present\)"/g;
  const teamSections: { name: string; startIndex: number }[] = [];
  let teamMatch: RegExpExecArray | null;

  while ((teamMatch = teamPattern.exec(html)) !== null) {
    teamSections.push({ name: teamMatch[1].trim(), startIndex: teamMatch.index });
  }

  for (let i = 0; i < teamSections.length; i++) {
    const section = teamSections[i];
    const endIndex = i + 1 < teamSections.length ? teamSections[i + 1].startIndex : html.length;
    const sectionHtml = html.slice(section.startIndex, endIndex);

    const nameUpper = section.name.toUpperCase();
    const abbrev = abbrevMap[nameUpper];
    if (!abbrev) {
      unmapped.push(section.name);
      continue;
    }
    if (teams[abbrev]) continue;

    const colors = extractCurrentColors(sectionHtml);
    if (colors.length === 0) continue;

    teams[abbrev] = {
      primary: colors[0],
      secondary: colors.length > 1 ? colors[1] : colors[0],
      name: toTitleCase(section.name),
    };
  }

  return { teams, unmapped };
}

/**
 * Parse an NCAA conference page.
 *
 * Structure:
 *   <div class="collapseomatic" title="THE UNIVERSITY OF ALABAMA"><strong>THE UNIVERSITY OF ALABAMA</strong></div>
 *   <div class="collapseomatic_content">
 *     <div class="collapseomatic" title="ATHLETICS COLORS">ATHLETICS COLORS</div>
 *     <div class="collapseomatic_content">
 *       <div class="collapseomatic" title="2015 through present: <strong>Crimson, White</strong>">
 *         ... acb-box divs with colors ...
 */
function parseNcaaPage(html: string, abbrevMap: Record<string, string>): ParseResult {
  const teams: Record<string, TeamColors> = {};
  const unmapped: string[] = [];

  // NCAA school headers: id="..." title="SCHOOL NAME" or title="&#9989; SCHOOL NAME"
  // The title is a plain school name, optionally prefixed with a checkmark emoji
  const schoolPattern = /class="collapseomatic\s*"[^>]*title="(?:&#9989;|✅)?\s*([^"]+)"[^>]*>/g;
  const schoolSections: { name: string; startIndex: number }[] = [];
  let match: RegExpExecArray | null;

  while ((match = schoolPattern.exec(html)) !== null) {
    const name = match[1].trim();
    if (isSchoolName(name)) {
      schoolSections.push({ name, startIndex: match.index });
    }
  }

  for (let i = 0; i < schoolSections.length; i++) {
    const section = schoolSections[i];
    const endIndex = i + 1 < schoolSections.length ? schoolSections[i + 1].startIndex : html.length;
    const sectionHtml = html.slice(section.startIndex, endIndex);

    const nameUpper = section.name.toUpperCase();
    const nameClean = nameUpper.replace(/\s*\([^)]*\)\s*$/, '').trim();

    const abbrev = abbrevMap[nameUpper] || abbrevMap[nameClean];
    if (!abbrev) {
      unmapped.push(section.name);
      continue;
    }
    if (teams[abbrev]) continue;

    // For NCAA, look in the "ATHLETICS COLORS" subsection first
    const colors = extractNcaaColors(sectionHtml);
    if (colors.length === 0) continue;

    teams[abbrev] = {
      primary: colors[0],
      secondary: colors.length > 1 ? colors[1] : colors[0],
      name: toTitleCase(section.name),
    };
  }

  return { teams, unmapped };
}

/**
 * Check if a title looks like a school name rather than a subsection header.
 */
function isSchoolName(name: string): boolean {
  const upper = name.toUpperCase();
  // Must not look like an era: starts with year
  if (/^\d{4}/.test(upper)) return false;
  // If it contains "university", "college", "institute", or "academy" it's likely a school
  // But exclude subsection headers that happen to contain these words
  if (/VAULT|GRAPHICS/.test(upper)) return false;
  if (/UNIVERSITY|COLLEGE|INSTITUTE|ACADEMY/.test(upper)) return true;
  // Exclude known subsection/category headers and conference names
  const excludePatterns = [
    /COLORS$/, /NICKNAME/, /MASCOT/, /MARK COLORS/, /CAMPAIGN/,
    /CONFERENCE\b/, /LEAGUE\b/, /TOURNAMENT/, /CHAMPIONSHIP/,
    /NETWORK/, /BOWL$/, /CLASSIC$/, /SERIES$/, /SHOWDOWN/,
    /CUP$/, /GAME COLORS/, /RIVALRY/, /SPIRIT/, /VENUE/,
    /VINTAGE/, /YOUTH/, /UNOFFICIAL/, /SUPPLEMENTAL/, /MISCELLANEOUS/,
    /CREST/, /SEAL/, /SHIELD/, /BATTLE/, /SPORT-SPECIFIC/,
    /COMMEMORATIVE/, /ADDITIONAL/, /ALTERNATE/,
  ];
  if (excludePatterns.some(p => p.test(upper))) return false;
  return false;
}

/**
 * For NCAA pages, extract colors from the "ATHLETICS COLORS" subsection.
 * Within that, find the first "through present" era, or fall back to the first era.
 */
function extractNcaaColors(schoolSectionHtml: string): string[] {
  // Try to find the "ATHLETICS COLORS" subsection
  const athleticsIdx = schoolSectionHtml.indexOf('title="ATHLETICS COLORS"');
  if (athleticsIdx !== -1) {
    // Use the section after ATHLETICS COLORS header
    const afterAthletics = schoolSectionHtml.slice(athleticsIdx);
    const colors = extractCurrentColors(afterAthletics);
    if (colors.length > 0) return colors;
  }

  // Fall back to extracting from the whole school section
  return extractCurrentColors(schoolSectionHtml);
}

/**
 * Extract hex colors from the first (most recent) era section.
 * Era patterns: "2025-2026 through present" (pro) or "2015 through present" (NCAA)
 */
function extractCurrentColors(sectionHtml: string): string[] {
  // Match era headers with year patterns
  const eraPattern = /title="(\d{4}(?:-\d{4})?\s+through[^"]*)"[^>]*>.*?<\/div>\s*<div[^>]*class="collapseomatic_content[^"]*"[^>]*>/gs;
  let eraMatch: RegExpExecArray | null;
  const eras: { title: string; startIndex: number }[] = [];

  while ((eraMatch = eraPattern.exec(sectionHtml)) !== null) {
    eras.push({ title: eraMatch[1], startIndex: eraMatch.index });
  }

  if (eras.length === 0) {
    return extractHexFromHtml(sectionHtml);
  }

  // Prefer "through present"
  let targetEra = eras.find(e => /through present/i.test(e.title));
  if (!targetEra) targetEra = eras[0];

  const targetIndex = eras.indexOf(targetEra);
  const eraEndIndex = targetIndex + 1 < eras.length
    ? eras[targetIndex + 1].startIndex
    : sectionHtml.length;

  return extractHexFromHtml(sectionHtml.slice(targetEra.startIndex, eraEndIndex));
}

/**
 * Extract hex color codes from acb-box background-color inline styles.
 */
function extractHexFromHtml(html: string): string[] {
  const colors: string[] = [];
  const boxPattern = /class="acb-box"[^>]*style="[^"]*background-color:\s*(#[0-9A-Fa-f]{3,6})/gi;
  let match: RegExpExecArray | null;

  while ((match = boxPattern.exec(html)) !== null) {
    let hex = match[1].toUpperCase();
    if (/^#[0-9A-Fa-f]{3}$/.test(hex)) {
      hex = `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`;
    }
    if (HEX_REGEX.test(hex)) {
      colors.push(hex);
    }
  }

  return colors;
}

function toTitleCase(str: string): string {
  return str
    .toLowerCase()
    .replace(/(?:^|\s|[-/])\S/g, c => c.toUpperCase())
    .replace(/\b(Of|The|And|At|In|For|A|An)\b/g, w => w.toLowerCase())
    .replace(/^./, c => c.toUpperCase());
}
