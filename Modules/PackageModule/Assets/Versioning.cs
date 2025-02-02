#nullable enable
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace Versioning
{
    public enum VersionType { Ideal, General, Complex }

    public interface IVersion : IComparable<IVersion>
    {
        VersionType Type { get; }
        IEnumerable<IComparable> GetComponents();
    }

    public class VersionChunk : IComparable<VersionChunk>
    {
        public uint? Numeric { get; }
        public string Value { get; }

        public VersionChunk(uint numeric) { Numeric = numeric; Value = numeric.ToString(); }
        public VersionChunk(string value) { Value = value; Numeric = null; }

        public int CompareTo(VersionChunk? other)
        {
            if (other is null) return 1;
            if (Numeric.HasValue && other.Numeric.HasValue) return Numeric.Value.CompareTo(other.Numeric.Value);
            return string.Compare(Value, other.Value, StringComparison.Ordinal);
        }

        public override string ToString() => Value;
    }

    public class SemVer : IVersion
    {
        public uint Major { get; }
        public uint Minor { get; }
        public uint Patch { get; }
        public string? PreRelease { get; }
        public string? Metadata { get; }
        public VersionType Type => VersionType.Ideal;

        public SemVer(uint major, uint minor, uint patch, string? preRelease = null, string? metadata = null)
        {
            Major = major;
            Minor = minor;
            Patch = patch;
            PreRelease = preRelease;
            Metadata = metadata;
        }

        public int CompareTo(IVersion? other)
        {
            if (other is null)
            {
                return 1;
            }
            else if (other is SemVer sv)
            {
                var major = Major.CompareTo(sv.Major);
                if (major != 0) return major;

                var minor = Minor.CompareTo(sv.Minor);
                if (minor != 0) return minor;

                var patch = Patch.CompareTo(sv.Patch);
                if (patch != 0) return patch;

                if (PreRelease is null) return sv.PreRelease is null ? 0 : 1;
                if (sv.PreRelease is null) return -1;
                return string.Compare(PreRelease, sv.PreRelease, StringComparison.Ordinal);
            }
            else
            {
                var components = GetComponents().GetEnumerator();
                var otherComponents = other.GetComponents().GetEnumerator();

                while (true)
                {
                    var componentsHasValue = components.MoveNext();
                    var otherComponentsHasValue = otherComponents.MoveNext();
                    if (!componentsHasValue && !otherComponentsHasValue) return 0;
                    else if (!componentsHasValue) return -1;
                    else if (!otherComponentsHasValue) return 1;
                    else
                    {
                        var cmp = CompareComponents(components.Current, otherComponents.Current);
                        if (cmp != 0) return cmp;
                    }
                }
            }
        }

        private int CompareComponents(IComparable a, IComparable b)
        {
            if (a is uint an && b is uint bn) return an.CompareTo(bn);
            if (a is string as_ && b is string bs) return string.Compare(as_, bs, StringComparison.Ordinal);
            return a is null ? 1 : -1;
        }

        public IEnumerable<IComparable> GetComponents() => new IComparable[] { Major, Minor, Patch };

        public static SemVer? Parse(string input)
        {
            var match = Regex.Match(input, @"^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.-]+))?(?:\+([a-zA-Z0-9.-]+))?$");
            if (!match.Success) return null;

            return new SemVer(
                uint.Parse(match.Groups[1].Value),
                uint.Parse(match.Groups[2].Value),
                uint.Parse(match.Groups[3].Value),
                match.Groups[4].Success ? match.Groups[4].Value : null,
                match.Groups[5].Success ? match.Groups[5].Value : null
            );
        }

        public override string ToString() => $"{Major}.{Minor}.{Patch}{(PreRelease is not null ? $"-{PreRelease}" : "")}{(Metadata is not null ? $"+{Metadata}" : "")}";
    }

    public class GeneralVersion : IVersion
    {
        public uint? Epoch { get; }
        public List<VersionChunk> Chunks { get; }
        public string? Metadata { get; }
        public VersionType Type => VersionType.General;

        public GeneralVersion(uint? epoch, List<VersionChunk> chunks, string? metadata = null)
        {
            Epoch = epoch;
            Chunks = chunks;
            Metadata = metadata;
        }

        public int CompareTo(IVersion? other)
        {
            if (other is null)
            {
                return 1;
            }
            else if (other is GeneralVersion gv)
            {
                var epochCompare = (Epoch ?? 0).CompareTo(gv.Epoch ?? 0);
                if (epochCompare != 0) return epochCompare;

                for (int i = 0; i < Math.Max(Chunks.Count, gv.Chunks.Count); i++)
                {
                    var left = i < Chunks.Count ? Chunks[i] : null;
                    var right = i < gv.Chunks.Count ? gv.Chunks[i] : null;

                    var cmp = CompareChunks(left, right);
                    if (cmp != 0) return cmp;
                }
                return 0;
            }
            else
            {
                var components = GetComponents().GetEnumerator();
                var otherComponents = other.GetComponents().GetEnumerator();

                while (true)
                {
                    var componentsHasValue = components.MoveNext();
                    var otherComponentsHasValue = otherComponents.MoveNext();
                    if (!componentsHasValue && !otherComponentsHasValue) return 0;
                    else if (!componentsHasValue) return -1;
                    else if (!otherComponentsHasValue) return 1;
                    else
                    {
                        var cmp = CompareComponents(components.Current, otherComponents.Current);
                        if (cmp != 0) return cmp;
                    }
                }
            }
        }

        private static int CompareChunks(VersionChunk? a, VersionChunk? b)
        {
            if (a is null) return b is null ? 0 : -1;
            if (b is null) return 1;
            return a.CompareTo(b);
        }

        private int CompareComponents(object a, object b)
        {
            if (a is uint au && b is uint bu) return au.CompareTo(bu);
            if (a is string astr && b is string bstr) return string.Compare(astr, bstr, StringComparison.Ordinal);
            return a is null ? 1 : -1;
        }

        public IEnumerable<IComparable> GetComponents()
        {
            foreach (var chunk in Chunks)
            {
                if (chunk.Numeric.HasValue) yield return chunk.Numeric.Value;
                else yield return chunk.Value;
            }
        }

        public static GeneralVersion? Parse(string input)
        {
            var match = Regex.Match(input, @"^(?:(\d+):)?([a-zA-Z0-9.+_-]+?)(?:-([a-zA-Z0-9.+_-]*))?(?:\+([a-zA-Z0-9.+_-]+))?$");
            if (!match.Success) return null;

            return new GeneralVersion(
                match.Groups[1].Success ? uint.Parse(match.Groups[1].Value) : null,
                ParseChunks(match.Groups[2].Value),
                match.Groups[4].Success ? match.Groups[4].Value : null
            );
        }

        private static List<VersionChunk> ParseChunks(string input)
        {
            var chunks = new List<VersionChunk>();
            foreach (var part in input.Split('.'))
            {
                if (uint.TryParse(part, out uint num))
                    chunks.Add(new VersionChunk(num));
                else
                    chunks.Add(new VersionChunk(part));
            }
            return chunks;
        }

        public override string ToString() => $"{(Epoch.HasValue ? $"{Epoch}:" : "")}{string.Join(".", Chunks)}{(Metadata is not null ? $"+{Metadata}" : "")}";
    }

    public class ComplexVersion : IVersion
    {
        public string Raw { get; }
        public VersionType Type => VersionType.Complex;

        public ComplexVersion(string raw) => Raw = raw;

        public int CompareTo(IVersion? other)
        {
            return other is ComplexVersion cv
              ? string.Compare(Raw, cv.Raw, StringComparison.Ordinal)
              : string.Compare(Raw, other?.ToString() ?? string.Empty, StringComparison.Ordinal);
        }

        public IEnumerable<IComparable> GetComponents() => new[] { Raw };

        public override string ToString() => Raw;
    }

    public class Versioning : IVersion
    {
        public IVersion Version { get; }
        public VersionType Type => Version?.Type ?? VersionType.Complex;

        public Versioning(IVersion version) => Version = version;

        public int CompareTo(IVersion? other)
        {
            if (other is Versioning v) return Version.CompareTo(v.Version);
            return Version.CompareTo(other);
        }

        public IEnumerable<IComparable> GetComponents() => Version.GetComponents();

        public static Versioning Parse(string input)
        {
            return new Versioning(
              SemVer.Parse(input) as IVersion ??
              GeneralVersion.Parse(input) ??
              new ComplexVersion(input) as IVersion
            );
        }

        public override string ToString() => Version?.ToString() ?? string.Empty;
    }
}
