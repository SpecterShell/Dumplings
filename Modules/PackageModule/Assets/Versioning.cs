/*
This is an experimental adaption of https://github.com/fosskers/rs-versions to C#. Kudos to the original author Colin Woodbury.
The license of the original version, an MIT license, is attached:

MIT License

Copyright (c) 2021 Colin Woodbury

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Compared to the original version, this adaption has the following differences:
- The original version uses nom for parsing, while this version uses regular expressions.
- Another version type "Raw" is introduced to represent versions that are not fitted to the other three types,
  which splits the version into numeric and non-numeric chunks and compares them chunk by chunk.
- GeneralVersion::ToComplexVersion() also considers the metadata value.
- Some version downcastings are done by reparsing the string representation of the version as they may have different sets of separators.

TODO:
- Implement the IEquatable interface for all version types.
*/
#nullable enable
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace Dumplings.Versioning
{
    public enum VersionType { Semantic, General, Complex, Raw }

    public interface IVersion
    {
        VersionType Type { get; }
        public string ToString();
    }

    public enum ChunkType { Numeric, Alphanum }
    public class Chunk : IComparable<Chunk>
    {
        public ChunkType Type { get; }
        public string Alphanum { get; }
        public uint? Numeric { get; }

        internal Chunk(uint numeric) { Numeric = numeric; Alphanum = numeric.ToString(); Type = ChunkType.Numeric; }
        internal Chunk(string value) { Alphanum = value; Numeric = null; Type = ChunkType.Alphanum; }

        public static Chunk Parse(string input)
        {
            if (uint.TryParse(input, out uint num))
                return new Chunk(num);
            else
                return new Chunk(input);
        }

        public static bool TryParse(string input, out Chunk? chunk)
        {
            try
            {
                chunk = Parse(input);
                return true;
            }
            catch
            {
                chunk = null;
                return false;
            }
        }

        public uint? GetDigit()
        {
            return Numeric.HasValue ? Numeric : null;
        }

        public uint? GetPrefixDigit()
        {
            if (Numeric.HasValue) return Numeric;

            var match = Regex.Match(Alphanum, @"^(0|\d+)");
            return (match.Success && uint.TryParse(match.Groups[1].Value, out uint numeric)) ? numeric : null;
        }

        public uint? GetSuffixDigit()
        {
            if (Numeric.HasValue) return Numeric;

            var match = Regex.Match(Alphanum, @"^[a-zA-Z]+(0|\d+)");
            return (match.Success && uint.TryParse(match.Groups[1].Value, out uint numeric)) ? numeric : null;
        }

        public int CompareTo(Chunk? other)
        {
            if (other == null) return 1;
            else return Numeric.HasValue && other.Numeric.HasValue ? Numeric.Value.CompareTo(other.Numeric.Value) : string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
        }

        public int CompareToSemantic(Chunk? other)
        {
            if (other is null) return 1;
            if (Numeric.HasValue && other.Numeric.HasValue) return Numeric.Value.CompareTo(other.Numeric.Value);
            if (Numeric.HasValue && !other.Numeric.HasValue) return -1;
            if (!Numeric.HasValue && other.Numeric.HasValue) return 1;
            return string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
        }

        public int CompareToGeneral(Chunk? other)
        {
            if (other is null) return 1;
            if (Numeric.HasValue && other.Numeric.HasValue) return Numeric.Value.CompareTo(other.Numeric.Value);
            else if (Numeric.HasValue && !other.Numeric.HasValue)
            {
                var otherDigit = other.GetPrefixDigit();
                if (otherDigit is not null)
                {
                    var cmp = Numeric.Value.CompareTo(otherDigit.Value);
                    // 1.2.0 > 1.2.0rc1
                    return cmp == 0 ? 1 : cmp;
                }
                else return 1;
            }
            else if (!Numeric.HasValue && other.Numeric.HasValue)
            {
                var digit = GetPrefixDigit();
                if (digit is not null)
                {
                    var cmp = digit.Value.CompareTo(other.Numeric.Value);
                    // 1.2.0rc1 < 1.2.0
                    return cmp == 0 ? -1 : cmp;
                }
                else return -1;
            }
            else
            {
                if (Regex.IsMatch(Alphanum, $"^[a-zA-Z]") && Alphanum[0] == other.Alphanum[0])
                {
                    // r8 < r23
                    var digit = GetSuffixDigit();
                    var otherDigit = other.GetSuffixDigit();
                    return digit is not null && otherDigit is not null ? digit.Value.CompareTo(otherDigit.Value) : string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
                }
                else if (Regex.IsMatch(Alphanum, @"^\d") && Regex.IsMatch(other.Alphanum, @"^\d"))
                {
                    // 0rc1 < 1rc1
                    var digit = GetPrefixDigit();
                    var otherDigit = other.GetPrefixDigit();
                    return digit is not null && otherDigit is not null ? digit.Value.CompareTo(otherDigit.Value) : string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
                }
                else return string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
            }
        }

        public override string ToString() => Alphanum;
    }

    public enum ComplexChunkType { Digits, Rev, Plain }
    public class ComplexChunk : IComparable<ComplexChunk>
    {
        public ComplexChunkType Type { get; }
        public string Alphanum { get; }
        public uint? Numeric { get; }

        internal ComplexChunk(ComplexChunkType type, string alphanum, uint? numeric = null)
        {
            if (type == ComplexChunkType.Digits && numeric is null) throw new ArgumentException("A numeric value must be provided for a Digits type.");
            if (type == ComplexChunkType.Rev && numeric is null) throw new ArgumentException("A numeric value must be provided for a Rev type.");
            Type = type;
            Alphanum = alphanum;
            Numeric = numeric;
        }

        public static ComplexChunk Parse(string input)
        {
            var match = Regex.Match(input, @"^\d+$");
            if (match.Success && uint.TryParse(input, out uint num)) return new ComplexChunk(ComplexChunkType.Digits, input, num);

            match = Regex.Match(input, @"^r(\d+)$");
            if (match.Success && uint.TryParse(match.Groups[1].Value, out uint rev)) return new ComplexChunk(ComplexChunkType.Rev, input, rev);

            return new ComplexChunk(ComplexChunkType.Plain, input);
        }

        public static bool TryParse(string input, out ComplexChunk? chunk)
        {
            try
            {
                chunk = Parse(input);
                return true;
            }
            catch
            {
                chunk = null;
                return false;
            }
        }

        public uint? GetDigit()
        {
            return Numeric.HasValue ? Numeric : null;
        }

        public uint? GetPrefixDigit()
        {
            if (Numeric.HasValue) return Numeric;

            var match = Regex.Match(Alphanum, @"^(0|\d+)");
            return (match.Success && uint.TryParse(match.Groups[1].Value, out uint numeric)) ? numeric : null;
        }

        public uint? GetSuffixDigit()
        {
            if (Numeric.HasValue) return Numeric;

            var match = Regex.Match(Alphanum, @"^[a-zA-Z]+(0|\d+)");
            return (match.Success && uint.TryParse(match.Groups[1].Value, out uint numeric)) ? numeric : null;
        }

        public int CompareTo(ComplexChunk? other)
        {
            if (other is null) return 1;
            // Normal cases.
            else if (Type == ComplexChunkType.Digits && other.Type == ComplexChunkType.Digits)
            {
                if (!Numeric.HasValue || !other.Numeric.HasValue) throw new Exception("This should never happen.");
                return Numeric.Value.CompareTo(other.Numeric);
            }
            else if (Type == ComplexChunkType.Rev && other.Type == ComplexChunkType.Rev)
            {
                if (!Numeric.HasValue || !other.Numeric.HasValue) throw new Exception("This should never happen.");
                return Numeric.Value.CompareTo(other.Numeric);
            }
            // If I'm a concrete number and you're just a revision, then I'm greater no matter what
            else if (Type == ComplexChunkType.Digits && other.Type == ComplexChunkType.Rev) return 1;
            else if (Type == ComplexChunkType.Rev && other.Type == ComplexChunkType.Digits) return -1;
            // There's no sensible pairing, so we fall back to String-based comparison.
            else return string.Compare(Alphanum, other.Alphanum, StringComparison.Ordinal);
        }

        public override string ToString() => Alphanum;
    }

    public class Chunks : List<Chunk>, IComparable<Chunks>
    {
        public static Chunks Parse(string input)
        {
            var chunks = new Chunks();
            foreach (var part in input.Split('.')) chunks.Add(Chunk.Parse(part));
            return chunks;
        }

        public int CompareTo(Chunks? other)
        {
            if (other is null) return 1;

            for (int i = 0; i < Math.Max(Count, other.Count); i++)
            {
                var left = i < Count ? this[i] : null;
                var right = i < other.Count ? other[i] : null;

                if (left is not null && right is not null)
                {
                    var cmp = left.CompareToSemantic(right);
                    if (cmp != 0) return cmp;
                }
                // From the Semver spec: A larger set of pre-release fields has a higher precedence than a smaller set, if all the preceding identifiers are equal.
                else if (left is not null && right is null) return 1;
                else if (left is null && right is not null) return -1;
                else throw new Exception("This should never happen.");
            }

            return 0;
        }

        public ComplexChunks ToComplexChunks()
        {
            var chunkGroup = new ComplexChunks();
            foreach (var chunk in this) chunkGroup.Add(chunk.Numeric.HasValue ? new ComplexChunk(ComplexChunkType.Digits, chunk.Numeric.Value.ToString(), chunk.Numeric) : ComplexChunk.Parse(chunk.Alphanum));
            return chunkGroup;
        }

        public override string ToString() => string.Join('.', this);
    }

    public class Release : List<Chunk>, IComparable<Release>
    {
        public static Release Parse(string input)
        {
            var chunks = new Release();
            foreach (var part in input.Split('.')) chunks.Add(Chunk.Parse(part));
            return chunks;
        }

        public int CompareTo(Release? other)
        {
            if (other is null) return 1;

            for (int i = 0; i < Math.Max(Count, other.Count); i++)
            {
                var left = i < Count ? this[i] : null;
                var right = i < other.Count ? other[i] : null;

                if (left is not null && right is not null)
                {
                    var cmp = left.CompareToGeneral(right);
                    if (cmp != 0) return cmp;
                }
                // From the Semver spec: A larger set of pre-release fields has a higher precedence than a smaller set, if all the preceding identifiers are equal.
                else if (left is not null && right is null) return 1;
                else if (left is null && right is not null) return -1;
                else throw new Exception("This should never happen.");
            }

            return 0;
        }

        public ComplexChunks ToComplexChunks()
        {
            var chunkGroup = new ComplexChunks();
            foreach (var chunk in this) chunkGroup.Add(chunk.Numeric.HasValue ? new ComplexChunk(ComplexChunkType.Digits, chunk.Numeric.Value.ToString(), chunk.Numeric) : ComplexChunk.Parse(chunk.Alphanum));
            return chunkGroup;
        }

        public override string ToString() => string.Join('.', this);
    }

    public class ComplexChunks : List<ComplexChunk>, IComparable<ComplexChunks>
    {
        public static ComplexChunks Parse(string input)
        {
            var chunks = new ComplexChunks();
            foreach (var part in input.Split('.')) chunks.Add(ComplexChunk.Parse(part));
            return chunks;
        }

        public int CompareTo(ComplexChunks? other)
        {
            if (other is null) return 1;
            for (int i = 0; i < Math.Max(Count, other.Count); i++)
            {
                var left = i < Count ? this[i] : null;
                var right = i < other.Count ? other[i] : null;
                if (left is not null && right is not null)
                {
                    var cmp = left.CompareTo(right);
                    if (cmp != 0) return cmp;
                }
                else if (left is not null && right is null) return 1;
                else if (left is null && right is not null) return -1;
                else throw new Exception("This should never happen.");
            }
            return 0;
        }

        public override string ToString() => string.Join('.', this);
    }

    public class SemanticVersion : IVersion, IComparable<SemanticVersion>
    {
        public VersionType Type => VersionType.Semantic;
        public uint Major { get; }
        public uint Minor { get; }
        public uint Patch { get; }
        public Release? PreRelease { get; }
        public string? Metadata { get; }
        private static Regex VersionPattern = new(@"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$", RegexOptions.Compiled);

        internal SemanticVersion(uint major, uint minor, uint patch, Release? preRelease = null, string? metadata = null) { Major = major; Minor = minor; Patch = patch; PreRelease = preRelease; Metadata = metadata; }

        public static SemanticVersion Parse(string input)
        {
            var match = VersionPattern.Match(input);
            if (match.Success) return new SemanticVersion(
                uint.Parse(match.Groups[1].Value),
                uint.Parse(match.Groups[2].Value),
                uint.Parse(match.Groups[3].Value),
                match.Groups[4].Success ? Release.Parse(match.Groups[4].Value) : null,
                match.Groups[5].Success ? match.Groups[5].Value : null
            );
            else throw new ArgumentException("The input string is not a valid Semantic Version.");
        }

        public static bool TryParse(string input, out SemanticVersion? version)
        {
            try
            {
                version = Parse(input);
                return true;
            }
            catch
            {
                version = null;
                return false;
            }
        }

        public int CompareTo(SemanticVersion? other)
        {
            if (other is null) return 1;
            else
            {
                var major = Major.CompareTo(other.Major);
                if (major != 0) return major;

                var minor = Minor.CompareTo(other.Minor);
                if (minor != 0) return minor;

                var patch = Patch.CompareTo(other.Patch);
                if (patch != 0) return patch;

                // Build metadata does not affect version precendence, and pre-release versions have lower precedence than normal versions.
                if (PreRelease is null) return other.PreRelease is null ? 0 : 1;
                else if (other.PreRelease is null) return -1;
                else return PreRelease.CompareTo(other.PreRelease);
            }
        }

        public int CompareTo(GeneralVersion? other)
        {
            if (other is null) return 1;

            // A GeneralVersion with a non-zero epoch value is automatically greater than any SemanticVersion.
            if (other.Epoch.HasValue && other.Epoch > 0) return -1;

            // GetPrefixDigit() pulls a leading digit from the GeneralVersion's chunk if it could.
            // If it couldn't, that chunk is some string (perhaps a git hash) and is considered as marking a beta/prerelease version.
            // It is thus considered less than the SemanticVersion.
            var otherMajor = other.Chunks.Count > 0 ? other.Chunks[0].GetPrefixDigit() : null;
            if (otherMajor is null) return 1;
            var cmp = Major.CompareTo(otherMajor);
            if (cmp != 0) return cmp;

            var otherMinor = other.Chunks.Count > 1 ? other.Chunks[1].GetPrefixDigit() : null;
            if (otherMinor is null) return 1;
            cmp = Minor.CompareTo(otherMinor);
            if (cmp != 0) return cmp;

            var otherPatch = other.Chunks.Count > 2 ? other.Chunks[2].GetPrefixDigit() : null;
            if (otherPatch is null) return 1;
            cmp = Patch.CompareTo(otherPatch);
            if (cmp != 0) return cmp;

            // By this point, the major/minor/patch positions have all been equal.
            // If there is a fourth position, its type, not its value, will determine which overall version is greater.
            var other4thChunk = other.Chunks.Count > 3 ? other.Chunks[3] : null;
            // 1.2.3 < 1.2.3.0
            // 1.2.3 > 1.2.3.git
            if (other4thChunk is not null) return other4thChunk.Numeric.HasValue ? -1 : 1;

            return (PreRelease ?? []).CompareTo(other.Release ?? []);
        }

        public int CompareTo(ComplexVersion? other)
        {
            if (other is null) return 1;
            // Do our best to compare a SemVer and a Mess.
            // If we're lucky, the Mess will be well-formed enough to pull out SemVer-like values at each position, yielding sane comparisons.
            // Otherwise we're forced to downcast the SemVer into a Mess and let the String-based Ord instance of Mess handle things.
            var other1stChunkGroup = other.ChunkGroups.Count > 1 && other.Separators.Count > 0 && other.Separators[0] == Separator.Colon ? other.ChunkGroups[1] : other.ChunkGroups[0];

            var otherMajor = other1stChunkGroup.Count > 0 ? other1stChunkGroup[0].GetDigit() : null;
            if (otherMajor is null) return ToComplexVersion().CompareTo(other);
            var cmp = Major.CompareTo(otherMajor);
            if (cmp != 0) return cmp;

            var otherMinor = other1stChunkGroup.Count > 1 ? other1stChunkGroup[1].GetDigit() : null;
            if (otherMinor is null) return ToComplexVersion().CompareTo(other);
            cmp = Minor.CompareTo(otherMinor);
            if (cmp != 0) return cmp;

            if (other1stChunkGroup.Count > 2)
            {
                var otherPatch = other1stChunkGroup[2].GetDigit();
                if (otherPatch is null)
                {
                    // Even if we weren't able to extract a standalone patch number, we might still be able to find a number at the head of the Chunk in that position.
                    var otherPatchText = other1stChunkGroup[2].Alphanum;
                    var otherPatchChunk = Regex.IsMatch(otherPatchText, @"^[a-zA-Z0-9]+$") ? Chunk.Parse(otherPatchText) : null;
                    var otherPatchPre = otherPatchChunk?.GetPrefixDigit();
                    // This follows SemVer's rule that pre-releases have lower precedence.
                    if (otherPatchPre is not null) return Patch >= otherPatchPre ? 1 : -1;
                    // We were very close, but in the end the Mess had a nonsensical value in its patch position.
                    else return ToComplexVersion().CompareTo(other);
                }
                cmp = Patch.CompareTo(otherPatch);
                if (cmp != 0) return cmp;
                // If they've been equal up to this point, the Mess will by definition have more to it, meaning that it's more likely to be newer, despite its poor shape.
                else return ToComplexVersion().CompareTo(other);
            }
            else return ToComplexVersion().CompareTo(other);
        }

        public int CompareTo(RawVersion? other) => ToRawVersion().CompareTo(other);

        public GeneralVersion ToGeneralVersion() => new(null, [new Chunk(Major), new Chunk(Minor), new Chunk(Patch)], PreRelease, Metadata);

        public ComplexVersion ToComplexVersion() => ComplexVersion.Parse(ToString());

        public RawVersion ToRawVersion() => RawVersion.Parse(ToString());

        public override string ToString() => $"{Major}.{Minor}.{Patch}{(PreRelease is not null ? $"-{PreRelease}" : "")}{(Metadata is not null ? $"+{Metadata}" : "")}";
    }

    public class GeneralVersion : IVersion, IComparable<GeneralVersion>
    {
        public VersionType Type => VersionType.General;
        public uint? Epoch { get; }
        public Chunks Chunks { get; }
        public Release? Release { get; }
        public string? Metadata { get; }
        private static Regex VersionPattern = new(@"^(?:(0|[1-9]\d*):)?((?:0|[1-9]\d*|\d*[a-zA-Z][0-9a-zA-Z]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z][0-9a-zA-Z]*))*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$", RegexOptions.Compiled);

        internal GeneralVersion(uint? epoch, Chunks chunks, Release? release, string? metadata = null) { Epoch = epoch; Chunks = chunks; Release = release; Metadata = metadata; }

        public static GeneralVersion Parse(string input)
        {
            var match = VersionPattern.Match(input);
            if (match.Success) return new GeneralVersion(
                match.Groups[1].Success ? uint.Parse(match.Groups[1].Value) : null,
                Chunks.Parse(match.Groups[2].Value),
                match.Groups[3].Success ? Release.Parse(match.Groups[3].Value) : null,
                match.Groups[4].Success ? match.Groups[4].Value : null
            );
            else throw new ArgumentException("The input string is not a valid General Version.");
        }

        public static bool TryParse(string input, out GeneralVersion? version)
        {
            try
            {
                version = Parse(input);
                return true;
            }
            catch
            {
                version = null;
                return false;
            }
        }

        public int CompareTo(SemanticVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(GeneralVersion? other)
        {
            if (other is null) return 1;
            else
            {
                var cmp = (Epoch ?? 0).CompareTo(other.Epoch ?? 0);
                if (cmp != 0) return cmp;

                cmp = Chunks.CompareTo(other.Chunks);
                if (cmp != 0) return cmp;

                return (Release ?? []).CompareTo(other.Release ?? []);
            }
        }

        public int CompareTo(ComplexVersion? other)
        {
            if (other is null) return 1;

            // If we're lucky, we can pull specific numbers out of both inputs and accomplish the comparison without extra allocations.
            if (Epoch.HasValue && Epoch > 0 && other.ChunkGroups.Count > 0 && other.ChunkGroups[0].Count == 1)
            {
                // A near-nonsense case where a ComplexVersion is comprised of a single digit and nothing else. In this case its epoch would be considered 0.
                if (other.ChunkGroups.Count == 1) return 1;
                else if (other.Separators[0] == Separator.Colon)
                {
                    var otherEpoch = other.ChunkGroups[0][0].GetDigit();
                    if (otherEpoch is not null)
                    {
                        var cmp = Epoch.Value.CompareTo(otherEpoch.Value);
                        if (cmp != 0) return cmp;
                        return CompareToContinued(other);
                    }
                    // The ComplexVersion's epoch is a letter, etc.
                    else return 1;
                }
                // Similar nonsense, where the ComplexVersion had a single *something* before some non-colon separator. We then consider the epoch to be 0.
                else return 1;
            }
            // The GeneralVersion has an epoch but the ComplexVersion doesn't. Or if it does, it's malformed.
            else if (Epoch.HasValue && Epoch > 0) return 1;
            else return CompareToContinued(other);
        }

        private int CompareToContinued(ComplexVersion other)
        {
            // It's assumed the epoch check has already been done, and we're comparing the main parts of each version now.
            for (int i = 0; i < Math.Max(Chunks.Count, other.ChunkGroups[0].Count); i++)
            {
                var left = i < Chunks.Count ? Chunks[i].GetDigit() : null;
                var right = i < other.ChunkGroups[0].Count ? other.ChunkGroups[0][i].GetDigit() : null;

                if (left.HasValue && right.HasValue)
                {
                    var cmp = left.Value.CompareTo(right);
                    if (cmp != 0) return cmp;
                }
                // Sane values can't be extracted from one or both of the arguments.
                else if (left is not null || right is null) return ToComplexVersion().CompareTo(other);
                else throw new Exception("This should never happen.");
            }
            return ToComplexVersion().CompareTo(other);
        }

        public int CompareTo(RawVersion? other) => ToRawVersion().CompareTo(other);

        public ComplexVersion ToComplexVersion() => ComplexVersion.Parse(ToString());

        public RawVersion ToRawVersion() => RawVersion.Parse(ToString());

        public override string ToString() => $"{(Epoch.HasValue ? $"{Epoch}:" : "")}{Chunks}{(Release is not null ? $"-{Release}" : "")}{(Metadata is not null ? $"+{Metadata}" : "")}";
    }

    public enum Separator { Colon = ':', Hyphen = '-', Plus = '+', Underscore = '_', Tilde = '~' }
    public class ComplexVersion : IVersion, IComparable<ComplexVersion>
    {
        public VersionType Type => VersionType.Complex;
        public List<ComplexChunks> ChunkGroups { get; }
        public List<Separator> Separators { get; }
        private static Regex VersionPattern = new(@"^([a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*)(?:([:\-+_~])([a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*))*$", RegexOptions.Compiled);

        internal ComplexVersion(List<ComplexChunks> chunkGroups, List<Separator> separators) { ChunkGroups = chunkGroups; Separators = separators; }

        public static ComplexVersion Parse(string input)
        {
            var match = VersionPattern.Match(input);
            if (match.Success)
            {
                var chunkGroups = new List<ComplexChunks>();
                var separators = new List<Separator>();

                chunkGroups.Add(ComplexChunks.Parse(match.Groups[1].Value));

                for (int i = 0; i < match.Groups[3].Captures.Count; i++)
                {
                    separators.Add((Separator)match.Groups[2].Captures[i].Value[0]);
                    chunkGroups.Add(ComplexChunks.Parse(match.Groups[3].Captures[i].Value));
                }

                return new ComplexVersion(chunkGroups, separators);
            }
            else throw new ArgumentException("The input string is not a valid Complex Version.");
        }

        public static bool TryParse(string input, out ComplexVersion? version)
        {
            try
            {
                version = Parse(input);
                return true;
            }
            catch
            {
                version = null;
                return false;
            }
        }

        public int CompareTo(SemanticVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(GeneralVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(ComplexVersion? other)
        {
            if (other is null) return 1;
            else
            {
                for (int i = 0; i < Math.Max(ChunkGroups.Count, other.ChunkGroups.Count); i++)
                {
                    var leftGroup = i < ChunkGroups.Count ? ChunkGroups[i] : null;
                    var rightGroup = i < other.ChunkGroups.Count ? other.ChunkGroups[i] : null;
                    if (leftGroup is not null && rightGroup is not null)
                    {
                        var cmp = leftGroup.CompareTo(rightGroup);
                        if (cmp != 0) return cmp;
                    }
                    else if (leftGroup is not null && rightGroup is null) return 1;
                    else if (leftGroup is null && rightGroup is not null) return -1;
                    else throw new Exception("This should never happen.");
                }

                return 0;
            }
        }

        public int CompareTo(RawVersion? other) => ToRawVersion().CompareTo(other);

        public RawVersion ToRawVersion() => RawVersion.Parse(ToString());

        public override string ToString()
        {
            var result = new StringBuilder();
            for (int i = 0; i < ChunkGroups.Count; i++)
            {
                result.Append(ChunkGroups[i]);
                if (i < Separators.Count)
                {
                    switch (Separators[i])
                    {
                        case Separator.Colon:
                            result.Append(':');
                            break;
                        case Separator.Hyphen:
                            result.Append('-');
                            break;
                        case Separator.Plus:
                            result.Append('+');
                            break;
                        case Separator.Underscore:
                            result.Append('_');
                            break;
                        case Separator.Tilde:
                            result.Append('~');
                            break;
                    }
                }
            }
            return result.ToString();
        }
    }

    public class RawVersion : IVersion, IComparable<RawVersion>
    {
        public VersionType Type => VersionType.Raw;
        public List<Chunk> Chunks { get; }
        private static Regex VersionPattern = new(@"^(\d+|[^\d]+)+$", RegexOptions.Compiled);

        internal RawVersion(List<Chunk> chunks) { Chunks = chunks; }

        public static RawVersion Parse(string input)
        {
            var match = VersionPattern.Match(input);
            if (match.Success)
            {
                var chunks = new Chunks();
                for (int i = 0; i < match.Groups[1].Captures.Count; i++) chunks.Add(Chunk.Parse(match.Groups[1].Captures[i].Value));
                return new RawVersion(chunks);
            }
            else throw new ArgumentException("The input string is not a valid Complex Version.");
        }

        public static bool TryParse(string input, out RawVersion? version)
        {
            try
            {
                version = Parse(input);
                return true;
            }
            catch
            {
                version = null;
                return false;
            }
        }

        public int CompareTo(SemanticVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(GeneralVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(ComplexVersion? other) => other is not null ? -other.CompareTo(this) : 1;

        public int CompareTo(RawVersion? other)
        {
            if (other is null) return 1;

            for (int i = 0; i < Math.Max(Chunks.Count, other.Chunks.Count); i++)
            {
                var left = i < Chunks.Count ? Chunks[i] : null;
                var right = i < other.Chunks.Count ? other.Chunks[i] : null;
                if (left is not null && right is not null)
                {
                    var cmp = left.CompareTo(right);
                    if (cmp != 0) return cmp;
                }
                else if (left is not null && right is null) return 1;
                else if (left is null && right is not null) return -1;
                else throw new Exception("This should never happen.");
            }

            return 0;
        }

        public override string ToString() => string.Join("", Chunks);
    }

    public class Versioning : IComparable<Versioning>
    {
        public IVersion Version { get; }
        public VersionType Type => Version.Type;

        public Versioning(IVersion version) => Version = version;

        public static Versioning Parse(string input)
        {
            if (SemanticVersion.TryParse(input, out SemanticVersion? sv) && sv is not null) return new Versioning(sv);
            else if (GeneralVersion.TryParse(input, out GeneralVersion? gv) && gv is not null) return new Versioning(gv);
            else if (ComplexVersion.TryParse(input, out ComplexVersion? cv) && cv is not null) return new Versioning(cv);
            else if (RawVersion.TryParse(input, out RawVersion? rv) && rv is not null) return new Versioning(rv);
            else throw new ArgumentException("The input string is not a valid version.");
        }

        public int CompareTo(Versioning? other)
        {
            if (other is null) return 1;

            else if (Version is SemanticVersion sv && other.Version is SemanticVersion otherSV) return sv.CompareTo(otherSV);
            else if (Version is GeneralVersion gv && other.Version is GeneralVersion otherGV) return gv.CompareTo(otherGV);
            else if (Version is ComplexVersion cv && other.Version is ComplexVersion otherCV) return cv.CompareTo(otherCV);
            else if (Version is RawVersion rv && other.Version is RawVersion otherRV) return rv.CompareTo(otherRV);

            else if (Version is SemanticVersion sv1 && other.Version is GeneralVersion otherGV1) return sv1.CompareTo(otherGV1);
            else if (Version is GeneralVersion gv1 && other.Version is SemanticVersion otherSV1) return -otherSV1.CompareTo(gv1);

            else if (Version is SemanticVersion sv2 && other.Version is ComplexVersion otherCV2) return sv2.CompareTo(otherCV2);
            else if (Version is ComplexVersion cv2 && other.Version is SemanticVersion otherSV2) return -otherSV2.CompareTo(cv2);
            else if (Version is GeneralVersion gv2 && other.Version is ComplexVersion otherCV3) return gv2.CompareTo(otherCV3);
            else if (Version is ComplexVersion cv3 && other.Version is GeneralVersion otherGV3) return -otherGV3.CompareTo(cv3);

            else if (Version is SemanticVersion sv3 && other.Version is RawVersion otherRV2) return sv3.CompareTo(otherRV2);
            else if (Version is RawVersion rv2 && other.Version is SemanticVersion otherSV3) return -otherSV3.CompareTo(rv2);
            else if (Version is GeneralVersion gv3 && other.Version is RawVersion otherRV3) return gv3.CompareTo(otherRV3);
            else if (Version is RawVersion rv3 && other.Version is GeneralVersion otherGV4) return -otherGV4.CompareTo(rv3);
            else if (Version is ComplexVersion cv4 && other.Version is RawVersion otherRV4) return cv4.CompareTo(otherRV4);
            else if (Version is RawVersion rv4 && other.Version is ComplexVersion otherCV4) return -otherCV4.CompareTo(rv4);

            else throw new Exception($"Unsupported version type {Type}");
        }

        public override string ToString() => Version.ToString();
    }
}
